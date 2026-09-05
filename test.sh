echo "=== DEV ==="
./install.sh --dev 2>&1 | head -100

echo
echo "=== INSTALL SCRIPT ==="
sed -n '1,260p' install.sh

echo
echo "=== INSTALLED LAUNCHER ==="
cat /usr/local/bin/astra

echo
echo "=== /usr/local ASTRA ==="
find /usr/local -maxdepth 3 \( -name 'astra' -o -name 'router.sh' -o -name 'project.sh' \) -print 2>/dev/null