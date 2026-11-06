# Snapvault: a deliberately vulnerable PHP upload app for the insecure-file-upload
# lab. Apache + mod_php executes any .php under the web root - including the
# uploads directory - which is exactly what makes the bug exploitable.
FROM php:8.3.36-apache

COPY app/ /var/www/html/

# The uploads directory must exist and be writable by the web process; /flag is
# where a successful webshell proves code execution. World-writable /flag keeps
# it simple whatever uid PHP runs as.
RUN mkdir -p /var/www/html/uploads /flag \
 && chown -R www-data:www-data /var/www/html/uploads \
 && chmod 1777 /flag

RUN printf '%s\n' \
  '# Insecure file upload lab - fill these in after you get code execution.' \
  '' \
  '# TRUSTED_HEADER: which request header does the upload handler wrongly trust?' \
  'TRUSTED_HEADER=' \
  '' \
  '# BYPASS: in one phrase, how did you get a script past the check?' \
  '#   (think about the filename / its extension)' \
  'BYPASS=' \
  '' \
  '# FIX: name one correct defense against insecure upload' \
  'FIX=' \
  > /root/answers.txt

RUN printf '%s\n' \
  'echo "Lab insecure-file-upload: Snapvault is at http://localhost (use curl). Upload via POST /upload.php (field: photo)."' \
  'echo "Uploaded files are served + executed under /uploads/<name>. A webshell that runs writes /flag/solved."' \
  'echo "Record findings in /root/answers.txt, then from the host: ./lab check insecure-file-upload"' \
  >> /root/.bashrc
