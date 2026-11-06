# A Linux file server with PowerShell 7 and LabAD, a stand-in for the ActiveDirectory module.
# Always a pinned tag (never latest); PowerShell is a pinned release, checked against its published SHA-256.
FROM ubuntu:24.04
ARG TARGETARCH
ARG PWSH_VERSION=7.4.6
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl libicu74 less \
 && rm -rf /var/lib/apt/lists/*
RUN set -eu; \
    case "$TARGETARCH" in \
      arm64) a=arm64; sum=c0159b03e85f44ae1e7697818a011558da6c813d0aae848bf5ac13bf435d8624 ;; \
      amd64) a=x64;   sum=6f6015203c47806c5cc444c19d8ed019695e610fbd948154264bf9ca8e157561 ;; \
      *) echo "unsupported arch $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/pwsh.tgz "https://github.com/PowerShell/PowerShell/releases/download/v$PWSH_VERSION/powershell-$PWSH_VERSION-linux-$a.tar.gz"; \
    echo "$sum  /tmp/pwsh.tgz" | sha256sum -c -; \
    mkdir -p /opt/microsoft/powershell/7; \
    tar -xzf /tmp/pwsh.tgz -C /opt/microsoft/powershell/7; \
    chmod +x /opt/microsoft/powershell/7/pwsh; \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh; \
    rm /tmp/pwsh.tgz
ENV POWERSHELL_TELEMETRY_OPTOUT=1 POWERSHELL_UPDATECHECK=Off
COPY labad/LabAD.psd1 labad/LabAD.psm1 labad/directory.json /usr/local/share/powershell/Modules/LabAD/
RUN echo 'echo "Lab powershell-basics: type pwsh to start PowerShell. Answers go in /root/answers.txt. Check from the host with: ./lab check powershell-basics"' >> /root/.bashrc
WORKDIR /root
CMD ["sleep", "infinity"]
