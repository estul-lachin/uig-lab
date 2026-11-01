# Checks for hello-world (see templates/lab/check.sh for the rules).

section "hello.txt"
check "hello.txt exists" '[ -f /root/hello.txt ]' \
  "Create /root/hello.txt"
check "Content is exactly 'Hello, World!'" '[ "$(cat /root/hello.txt)" = "Hello, World!" ]' \
  "The file must contain the single line Hello, World! - nothing more"
check "Mode is 644" '[ "$(stat -c %a /root/hello.txt)" = 644 ]' \
  "Owner read/write, everyone else read-only"
