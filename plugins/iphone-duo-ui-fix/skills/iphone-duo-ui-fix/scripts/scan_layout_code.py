#!/usr/bin/env python3
"""
scan_layout_code.py — point at the layout code an iPhone Duo fix has to read, so screens
without a screenshot can be triaged from code. Read-only; prints KEY=VALUE lines.

Usage:
    python3 scripts/scan_layout_code.py <repo_root> [PATH ...] [--hits] [--like FILE] [--top N]

    PATH       files or folders to scan, relative to <repo_root> (default: lib/ when
               <repo_root>/pubspec.yaml exists, else the whole repo). A file named
               explicitly also gets its hit= lines.
    --hits     print hit= lines for folder scans too
    --like F   rank the other screens by the project-defined types they share with F
               (sibling screens built the same way); prints similar= lines
    --top N    file= or similar= lines to print (default 40 / 10)

Output:
    scanned_files=N
    file=<path> kind=screen|other risks=N adaptive=N patterns=<ids|->    most risks first
    hit=<path>:<line> rule=<id> pattern=<id|-> predicts="<likely defect on Duo>"
    more=<path> rule=<id> count=N                                        hits past the 5th
    like=<path> patterns=<ids|->
    similar=<path> score=S shared=<Type,...> patterns=<ids|->
    files_with_risks=N
    files_omitted=N

A hit says where to read, not that the screen is broken; adaptive>0 means the file already
branches on width somewhere. Pattern ids are the ones in references/layout-patterns.md.

Exit: 0 ok, 1 no .dart/.swift files under the paths, 2 usage error.
Stdlib only; works with the python3 that ships with Xcode Command Line Tools.
"""
import math
import os
import re
import sys
from collections import Counter

SKIP_DIRS = {"build", "DerivedData", "Pods", "Carthage", "node_modules", "ephemeral",
             "test", "integration_test", "test_driver"}
SKIP_SUFFIXES = (".g.dart", ".freezed.dart", ".gr.dart", ".mocks.dart", ".config.dart")
HITS_PER_RULE = 5
PATTERN_ORDER = ("global-nav", "list-detail", "cards-feed", "long-form", "bottom-sheet",
                 "primary-cta", "form", "media", "canvas-tools", "flex-mode")

# (rule id, regex, pattern id or None, predicted defect) — one line at a time
RULES = {
    ".dart": [
        ("window-size-math", r"MediaQuery\.(of\(context\)\.size|sizeOf\(context\))\.(width|height)\s*[*/]",
         None, "sized as a fraction of the window: oversized or cropped on the inner display"),
        ("height-arithmetic", r"(\bsize|sizeOf\(context\))\.height\s*-",
         None, "height worked out for a regular iPhone: content pushed below the visible area"),
        ("size-variable", r"\b(screen|device)(Width|Height|Size)\b",
         None, "window-size variable: check what it sizes"),
        ("screenutil-scaling", r"\b\d+(\.\d+)?\.(w|h|r|sp|sw|sh)\b",
         None, "flutter_screenutil scales with the window: text and spacing oversized on the inner display"),
        ("phone-width", r"\bwidth:\s*([3-9]\d\d|\d{4,})(\.\d+)?\b",
         None, "phone-sized fixed width: content or background stops short on the inner display"),
        ("fixed-grid-columns", r"crossAxisCount:\s*\d",
         "cards-feed", "fixed column count: a few enormous columns on the inner display"),
        ("bottom-tab-bar", r"\b(BottomNavigationBar|NavigationBar|CupertinoTabBar)\(",
         "global-nav", "bottom tab bar stretched across the inner display, items far apart"),
        ("full-width-button", r"Size\.fromHeight|SizedBox\(\s*width:\s*double\.infinity",
         "primary-cta", "full-width button stretched across the inner display"),
        ("space-between", r"MainAxisAlignment\.space(Between|Around|Evenly)",
         None, "children pushed to opposite edges of a wide window"),
        ("orientation-lock", r"setPreferredOrientations",
         None, "orientation lock: app rotated or pillarboxed on the inner display"),
        ("display-size", r"View\.of\(context\)\.display|\.displays\b|\bui\.window\b|\bwindow\.physicalSize",
         None, "reads the outer display, not the window the app has"),
    ],
    ".swift": [
        ("uiscreen-main", r"UIScreen\.main\b",
         None, "describes the outer display even on the inner one; stale after fold/unfold"),
        ("phone-frame", r"\.frame\(\s*width:\s*([3-9]\d\d|\d{4,})",
         None, "phone-sized fixed frame: band or cut-off on the inner display"),
        ("phone-constraint", r"(width|height)Anchor\.constraint\(equalToConstant:\s*([3-9]\d\d|\d{4,})",
         None, "phone-sized constraint: band or cut-off on the inner display"),
        ("device-size-check", r"bounds\.(width|height)\s*(==|<=|>=|<|>)\s*\d{3}",
         None, "device-size check: takes the wrong branch on both Duo displays"),
        ("orientation-for-layout", r"UIDevice\.current\.orientation|statusBarOrientation|interfaceOrientation\.is",
         None, "orientation used for layout: says nothing about the window on Duo"),
        ("orientation-override", r"supportedInterfaceOrientations",
         None, "orientation override: a portrait lock rotates or pillarboxes the app"),
        ("idiom-check", r"userInterfaceIdiom\s*==\s*\.(pad|phone)",
         None, "idiom check: Duo is .phone, so a layout kept behind .pad never shows on the inner display"),
        ("fixed-grid-columns", r"GridItem\(\.(flexible|fixed)|\b(itemsPerRow|numberOfColumns|columnCount)\s*[:=]\s*\d",
         "cards-feed", "fixed column count: a few enormous columns on the inner display"),
        ("hand-built-bar", r"\b(UITabBar|UIToolbar)\(\s*(\)|frame:)",
         "global-nav", "hand-placed bar: stays horizontal and stretched, never moves into the vertical bar"),
        ("text-only-bar-item", r"UIBarButtonItem\(\s*title:",
         None, "text-only bar item: dropped or blank in the vertical bar"),
        ("one-sided-inset", r"safeAreaInsets\.(left|right)\b",
         None, "one side's inset reused for both: content under the trailing rail on the outer display"),
        ("spread-out", r"\.distribution\s*=\s*\.(equalSpacing|fillEqually)|spacing:\s*[1-9]\d\d\b",
         None, "items spread across the full width of the inner display"),
    ],
}

# (pattern id, regexes that must all match the file, minimum matches of the first)
PATTERNS = {
    ".dart": [
        ("global-nav", [r"\b(BottomNavigationBar|NavigationBar|NavigationRail|CupertinoTabBar|CupertinoTabScaffold)\("], 1),
        ("list-detail", [r"\b(ListView|SliverList|ListTile)\b",
                         r"Navigator\.(of\(context\)\.)?push|\bpush(Named|Replacement)?\(|context\.(push|go)(Named)?\("], 1),
        ("cards-feed", [r"\b(GridView|SliverGrid|MasonryGridView|AlignedGridView)\b"], 1),
        ("cards-feed", [r"\b(ListView|SliverList)\b", r"\bCard\("], 1),
        ("long-form", [r"\b(Markdown|MarkdownBody|Html|HtmlWidget|SelectableText|WebViewWidget|InAppWebView)\("], 1),
        ("bottom-sheet", [r"\b(showModalBottomSheet|showBottomSheet|DraggableScrollableSheet|showCupertinoModalPopup|"
                          r"showMaterialModalBottomSheet|showBarModalBottomSheet|showCupertinoModalBottomSheet)\b"], 1),
        ("primary-cta", [r"persistentFooterButtons|Size\.fromHeight|SizedBox\(\s*width:\s*double\.infinity|"
                         r"bottomNavigationBar:\s*(SafeArea|Padding|Container|SizedBox|ElevatedButton|FilledButton)\("], 1),
        ("form", [r"\b(TextFormField|TextField|CupertinoTextField|DropdownButtonFormField)\("], 2),
        ("media", [r"\b(VideoPlayer|Chewie|BetterPlayer|YoutubePlayer|AgoraVideoView|RTCVideoView|VlcPlayer)\(|\bVideo\(\s*controller:"], 1),
        ("canvas-tools", [r"\b(CustomPaint|InteractiveViewer)\(", r"onPan(Start|Update)|onScaleUpdate|\bListener\("], 1),
        ("canvas-tools", [r"\b(Signature|DrawingBoard|ProImageEditor|PainterController|Scribble)\b"], 1),
        ("flex-mode", [r"\b(CameraPreview|MobileScanner|QRView|CameraAwesomeBuilder)\b"], 1),
    ],
    ".swift": [
        ("global-nav", [r"\bTabView\b|UITabBarController|\bUITabBar\b"], 1),
        ("list-detail", [r"\bList\s*[({]|\bUITableView\b|\bUICollectionView\b",
                         r"NavigationLink|navigationDestination|pushViewController|showDetailViewController"], 1),
        ("cards-feed", [r"LazyVGrid|\bGrid\s*\{|UICollectionViewFlowLayout|UICollectionViewCompositionalLayout"], 1),
        ("long-form", [r"WKWebView|\bWebView\(|\bWebPage\b|\bMarkdown\b|isEditable\s*=\s*false"], 1),
        ("bottom-sheet", [r"\.sheet\(|presentationDetents|sheetPresentationController|UISheetPresentationController"], 1),
        ("primary-cta", [r"safeAreaInset\(\s*edge:\s*\.bottom"], 1),
        ("form", [r"\bTextField\(|\bSecureField\(|\bUITextField\b|\bForm\s*\{"], 2),
        ("media", [r"\bAVPlayer\b|\bVideoPlayer\(|AVPlayerViewController|AVPlayerLayer"], 1),
        ("canvas-tools", [r"PKCanvasView|PKToolPicker|\bCanvas\s*\{"], 1),
        ("flex-mode", [r"AVCaptureVideoPreviewLayer|AVCaptureSession|DataScannerViewController"], 1),
    ],
}

# lines showing the file already branches on width (or uses a Duo helper)
ADAPTIVE = {
    ".dart": r"LayoutBuilder|NavigationRail|[Mm]axCrossAxisExtent|BoxConstraints\(\s*maxWidth|DuoLayout|"
             r"sizeOf\(context\)\.width\s*[<>]|\.maxWidth\s*[<>]|ResponsiveBreakpoints|ResponsiveBuilder|"
             r"AdaptiveLayout|FoldScaffold|AdaptiveNavigationScaffold|FoldTwoPane",
    ".swift": r"horizontalSizeClass|ViewThatFits|NavigationSplitView|UISplitViewController|GridItem\(\.adaptive|"
              r"readableContentGuide|AnyLayout|DuoCenteredColumn|DuoColumnContainer|containerRelativeFrame|"
              r"onGeometryChange|reservedRegions|\.inspector\(|maxWidth:\s*\d",
}

SCREEN = {
    ".dart": r"\b(Scaffold|CupertinoPageScaffold)\(|class\s+\w+(Page|Screen)\b",
    ".swift": r":\s*(UIViewController|UITableViewController|UICollectionViewController)\b|class\s+\w+ViewController\b|"
              r"struct\s+\w+(Screen|Page)\s*:\s*View\b|\.navigationTitle\(|\bNavigationStack\b",
}

TYPEDEF = {
    ".dart": r"^\s*(?:(?:abstract|sealed|base|final|interface|mixin)\s+)*(?:class|mixin|enum|typedef)\s+([A-Z]\w*)",
    ".swift": r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|private|fileprivate|internal|open|final|indirect|package)\s+)*"
              r"(?:class|struct|enum|protocol|actor|typealias)\s+([A-Z]\w*)",
}
IDENT = re.compile(r"\b[A-Z]\w*\b")

RULES_C = {e: [(i, re.compile(r), p, d) for i, r, p, d in v] for e, v in RULES.items()}
PATTERNS_C = {e: [(i, [re.compile(r) for r in rs], n) for i, rs, n in v] for e, v in PATTERNS.items()}
ADAPTIVE_C = {e: re.compile(r) for e, r in ADAPTIVE.items()}
SCREEN_C = {e: re.compile(r) for e, r in SCREEN.items()}
TYPEDEF_C = {e: re.compile(r, re.M) for e, r in TYPEDEF.items()}


def skip_dir(name):
    return name.startswith(".") or name in SKIP_DIRS or name.endswith("Tests")


def collect(root, paths):
    files, explicit, missing = [], set(), []
    for p in paths:
        ap = os.path.normpath(p if os.path.isabs(p) else os.path.join(root, p))
        if os.path.isfile(ap):
            if os.path.splitext(ap)[1] in RULES:
                files.append(ap)
                explicit.add(ap)
        elif os.path.isdir(ap):
            for d, dirs, names in os.walk(ap):
                dirs[:] = sorted(x for x in dirs if not skip_dir(x))
                for n in sorted(names):
                    if os.path.splitext(n)[1] in RULES and not n.endswith(SKIP_SUFFIXES):
                        files.append(os.path.join(d, n))
        else:
            missing.append(p)
    seen, unique = set(), []
    for f in files:
        if f not in seen:
            seen.add(f)
            unique.append(f)
    return unique, explicit, missing


def analyse(path, root):
    ext = os.path.splitext(path)[1]
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError:
        lines = []
    code = [(i, l) for i, l in enumerate(lines, 1) if not l.lstrip().startswith(("//", "/*", "*"))]
    body = "\n".join(l for _, l in code)
    hits = []
    for rid, rx, pat, pred in RULES_C[ext]:
        hits.extend((i, rid, pat, pred) for i, l in code if rx.search(l))
    hits.sort()
    patterns = {pat for _, _, pat, _ in hits if pat}
    for pid, rxs, min_n in PATTERNS_C[ext]:
        if len(rxs[0].findall(body)) >= min_n and all(r.search(body) for r in rxs[1:]):
            patterns.add(pid)
    defined = set(TYPEDEF_C[ext].findall(body))
    return {
        "path": path,
        "rel": os.path.relpath(path, root),
        "kind": "screen" if SCREEN_C[ext].search(body) else "other",
        "hits": hits,
        "patterns": [p for p in PATTERN_ORDER if p in patterns],
        "adaptive": sum(1 for _, l in code if ADAPTIVE_C[ext].search(l)),
        "defined": defined,
        "used": set(IDENT.findall(body)) - defined,
    }


def pattern_list(a):
    return ",".join(a["patterns"]) or "-"


def print_hits(a):
    per_rule = Counter()
    for line, rid, pat, pred in a["hits"]:
        per_rule[rid] += 1
        if per_rule[rid] <= HITS_PER_RULE:
            print('hit=%s:%d rule=%s pattern=%s predicts="%s"' % (a["rel"], line, rid, pat or "-", pred))
    for rid, n in sorted(per_rule.items()):
        if n > HITS_PER_RULE:
            print("more=%s rule=%s count=%d" % (a["rel"], rid, n - HITS_PER_RULE))


def print_similar(target, analyses, top):
    project_types = set().union(*(a["defined"] for a in analyses))
    used = {a["path"]: a["used"] & project_types for a in analyses}
    df = Counter(t for a in analyses for t in used[a["path"]])
    n = len(analyses)
    weight = {t: math.log(float(n) / c) for t, c in df.items()}
    mine = used[target["path"]]
    ranked = []
    for a in analyses:
        if a is target or a["kind"] != "screen":
            continue
        shared = sorted(mine & used[a["path"]], key=lambda t: (-weight[t], t))
        score = sum(weight[t] for t in shared) + len(set(target["patterns"]) & set(a["patterns"]))
        if score > 0:
            ranked.append((score, a, shared))
    ranked.sort(key=lambda r: (-r[0], r[1]["rel"]))
    print("like=%s patterns=%s" % (target["rel"], pattern_list(target)))
    for score, a, shared in ranked[:top]:
        print("similar=%s score=%.1f shared=%s patterns=%s"
              % (a["rel"], score, ",".join(shared[:6]) or "-", pattern_list(a)))
    print("files_omitted=%d" % max(0, len(ranked) - top))


def parse(argv):
    args = argv[1:]
    if not args or args[0] in ("-h", "--help"):
        return None
    opts = {"root": args[0], "paths": [], "hits": False, "like": None, "top": None}
    i = 1
    while i < len(args):
        a = args[i]
        if a == "--hits":
            opts["hits"] = True
        elif a in ("--like", "--top"):
            if i + 1 >= len(args):
                return None
            i += 1
            if a == "--like":
                opts["like"] = args[i]
            elif args[i].isdigit():
                opts["top"] = int(args[i])
            else:
                return None
        elif a.startswith("--"):
            return None
        else:
            opts["paths"].append(a)
        i += 1
    return opts


def main(argv):
    opts = parse(argv)
    if opts is None:
        print(__doc__)
        return 2
    root = os.path.abspath(opts["root"])
    if not os.path.isdir(root):
        print("not a directory: %s" % root, file=sys.stderr)
        return 2
    paths = opts["paths"]
    if not paths:
        flutter = os.path.isfile(os.path.join(root, "pubspec.yaml")) and os.path.isdir(os.path.join(root, "lib"))
        paths = ["lib"] if flutter else ["."]
    if opts["like"]:
        paths = paths + [opts["like"]]

    files, explicit, missing = collect(root, paths)
    for p in missing:
        print("missing_path=%s" % p)
    if not files:
        print("scanned_files=0")
        return 1
    analyses = [analyse(f, root) for f in files]
    print("scanned_files=%d" % len(analyses))

    if opts["like"]:
        lp = opts["like"]
        lp = os.path.normpath(lp if os.path.isabs(lp) else os.path.join(root, lp))
        target = next((a for a in analyses if a["path"] == lp), None)
        if target is None:
            print("like_not_found=%s" % opts["like"], file=sys.stderr)
            return 2
        print_similar(target, analyses, opts["top"] or 10)
        return 0

    top = opts["top"] or 40
    rows = [a for a in analyses
            if a["path"] in explicit or a["kind"] == "screen" or a["hits"] or a["patterns"]]
    rows.sort(key=lambda a: (-len(a["hits"]), a["kind"] != "screen", a["rel"]))
    for a in rows[:top]:
        print("file=%s kind=%s risks=%d adaptive=%d patterns=%s"
              % (a["rel"], a["kind"], len(a["hits"]), a["adaptive"], pattern_list(a)))
        if opts["hits"] or a["path"] in explicit:
            print_hits(a)
    print("files_with_risks=%d" % sum(1 for a in analyses if a["hits"]))
    print("files_omitted=%d" % max(0, len(rows) - top))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
