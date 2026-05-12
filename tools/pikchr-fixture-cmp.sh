#!/usr/bin/env zsh
set -euo pipefail

repo=${0:A:h:h}
cd "$repo"

out_dir=${OUT_DIR:-"$repo/zig-out/pikchr-fixtures"}
stop_after=${STOP_AFTER:-0}
strict_status=${STRICT_STATUS:-0}

mkdir -p "$out_dir/c" "$out_dir/z" "$out_dir/err" "$out_dir/diff"
manifest="$out_dir/manifest.txt"
: > "$manifest"

print "building zig executable..."
zig build >/dev/null

zig_exe="$repo/zig-out/bin/pikchresque"
if [[ ! -x "$zig_exe" ]]; then
  print -u2 "missing executable: $zig_exe"
  print -u2 "expected 'zig build' to install the command-line tool there"
  exit 2
fi

typeset -a files
while IFS= read -r file; do
  files+=("$file")
done < <(find -L piks -type f \( -name '*.pik' -o -name '*.pikchr' \) -print | LC_ALL=C sort)

print "fixture output: $out_dir"
print "fixture count: $#files"

ok=0
fail=0
status_mismatch=0

for file in "${files[@]}"; do
  rel=$file
  safe=${rel//\//__}
  safe=${safe//./_}

  c_out="$out_dir/c/$safe.out"
  z_out="$out_dir/z/$safe.out"
  c_err="$out_dir/err/$safe.c.err"
  z_err="$out_dir/err/$safe.z.err"
  diff_out="$out_dir/diff/$safe.diff"

  print -- "$rel" >> "$manifest"

  set +e
  ./pikchr/pikchr --svg-only "$file" > "$c_out" 2> "$c_err"
  c_status=$?
  "$zig_exe" --svg-only "$file" > "$z_out" 2> "$z_err"
  z_status=$?
  set -e

  if ! cmp -s "$c_out" "$z_out"; then
    fail=$((fail + 1))
    print "DIFF $rel"
    diff -u "$c_out" "$z_out" > "$diff_out" || true
    sed -n '1,80p' "$diff_out"
  else
    ok=$((ok + 1))
  fi

  if [[ "$c_status" != "$z_status" ]]; then
    status_mismatch=$((status_mismatch + 1))
    print "STATUS $rel c=$c_status z=$z_status"
    if [[ "$strict_status" != 0 ]]; then
      fail=$((fail + 1))
    fi
  fi

  if [[ "$stop_after" != 0 && "$fail" -ge "$stop_after" ]]; then
    break
  fi
done

print "ok=$ok fail=$fail status_mismatch=$status_mismatch"
print "manifest=$manifest"

[[ "$fail" == 0 ]]
