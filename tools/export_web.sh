#!/bin/bash
# Export the companion and publish it in a fresh build folder, so phones never run a cached old build.
set -e
ROOT=/home/claude/tonifc
B=b$(date +%s)
cd $ROOT/godot
rm -rf $ROOT/docs/companion/app && mkdir -p $ROOT/docs/companion/app
sed -i 's#export_path="../docs/companion/[^"]*"#export_path="../docs/companion/app/index.html"#' export_presets.cfg
timeout 400 /tmp/Godot_v4.3-stable_linux.x86_64 --headless --path . --export-release "Web" 2>&1 | grep -iE "error" | grep -v alsa || true
cd $ROOT/docs/companion
rm -rf b[0-9]* index.* 2>/dev/null || true
mv app $B
echo "$B" > version.txt
cat > index.html <<HTML
<!DOCTYPE html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes"><meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="PF27 Companion"><meta name="theme-color" content="#120a1c">
<link rel="apple-touch-icon" href="$B/index.apple-touch-icon.png">
<title>Prime Football 27 Companion</title>
<style>body{margin:0;background:#120a1c;color:#eef2f6;font-family:-apple-system,Segoe UI,Arial,sans-serif;display:flex;height:100vh;align-items:center;justify-content:center}</style>
</head><body><div>Loading Prime Football 27…</div>
<script>
// always open the newest build (version.txt is never cached), falling back to the one this page knows
var fallback = "$B";
fetch("version.txt?" + Date.now(), {cache: "no-store"}).then(function (r) { return r.text(); })
  .then(function (v) { location.replace((v.trim() || fallback) + "/index.html"); })
  .catch(function () { location.replace(fallback + "/index.html"); });
</script></body></html>
HTML
echo "published companion build $B"
