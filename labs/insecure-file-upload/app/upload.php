<?php
// VULNERABLE upload handler.
//
// The bug: it trusts the client-supplied Content-Type header and saves the file
// under its ORIGINAL filename into a directory the web server executes. None of
// the real checks are done - no magic-byte validation, no random server-side
// name, no storing outside the web root, no "never serve as executable".
//
// A safe version would read the real file content (magic bytes), reject anything
// that isn't truly an image, save it under a random name in a non-executable
// directory, and serve it with a forced image Content-Type.

$dir = __DIR__ . '/uploads';

if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !isset($_FILES['photo'])) {
    header('Location: index.php?msg=' . urlencode('POST a photo to upload.'));
    exit;
}

$f = $_FILES['photo'];
if ($f['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo "Upload error.";
    exit;
}

// The ONLY check: the client-sent Content-Type must look like an image.
// This header is entirely attacker-controlled.
if (strpos((string)$f['type'], 'image/') !== 0) {
    http_response_code(415);
    echo "Only image uploads are allowed (got Content-Type: " . htmlspecialchars((string)$f['type']) . ").";
    exit;
}

// Saved by its original filename, into a web-served + executable directory.
$name = basename($f['name']);
$dest = $dir . '/' . $name;
if (!move_uploaded_file($f['tmp_name'], $dest)) {
    http_response_code(500);
    echo "Could not store the file.";
    exit;
}

echo "Stored your photo at /uploads/" . htmlspecialchars($name);
