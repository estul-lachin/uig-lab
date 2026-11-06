<?php
// Snapvault - a deliberately vulnerable photo-sharing demo for the
// insecure-file-upload lab. The upload handler is in upload.php.
$msg = isset($_GET['msg']) ? htmlspecialchars($_GET['msg']) : '';
?>
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Snapvault</title></head>
<body>
<header><strong>Snapvault</strong> &middot; share your photos</header>
<h1>Upload a photo</h1>
<form method="post" enctype="multipart/form-data" action="upload.php">
  <input type="file" name="photo">
  <button type="submit">Upload</button>
</form>
<?php if ($msg) echo "<p>$msg</p>"; ?>
<p>Your uploads appear under <code>/uploads/&lt;filename&gt;</code>.</p>
</body>
</html>
