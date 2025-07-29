#!/bin/bash

# be new
apt-get update

# get software
apt-get install \
    unclutter \
    xorg \
    chromium \
    openbox \
    lightdm \
    locales \
    -y

# dir
mkdir -p /home/kiosk/.config/openbox 2>/dev/null || {
    echo "Could not create directory /home/kiosk/.config/openbox"
    exit 1
}

# create group (handle different systems)
if command -v groupadd >/dev/null 2>&1; then
    groupadd -f kiosk 2>/dev/null || echo "Group kiosk already exists or could not be created"
else
    echo "groupadd command not found, trying alternative methods"
    # Try to create group using addgroup (Debian/Ubuntu alternative)
    if command -v addgroup >/dev/null 2>&1; then
        addgroup --system kiosk 2>/dev/null || echo "Could not create kiosk group"
    fi
fi

# create user if not exists (handle different systems)
if id -u kiosk &>/dev/null; then
    echo "User kiosk already exists"
else
    if command -v useradd >/dev/null 2>&1; then
        useradd -m kiosk -g kiosk -s /bin/bash 2>/dev/null || echo "Could not create kiosk user"
    elif command -v adduser >/dev/null 2>&1; then
        # Debian/Ubuntu alternative
        adduser --system --group --home /home/kiosk --shell /bin/bash kiosk 2>/dev/null || echo "Could not create kiosk user"
    else
        echo "Neither useradd nor adduser found - manual user creation required"
        exit 1
    fi
fi 

# rights
chown -R kiosk:kiosk /home/kiosk 2>/dev/null || {
    echo "Could not set ownership of /home/kiosk - continuing anyway"
}

# remove virtual consoles
if [ -e "/etc/X11/xorg.conf" ]; then
    mv /etc/X11/xorg.conf /etc/X11/xorg.conf.backup
fi
cat > /etc/X11/xorg.conf << EOF
Section "ServerFlags"
    Option "DontVTSwitch" "true"
EndSection
EOF

# create config
if [ -e "/etc/lightdm/lightdm.conf" ]; then
    mv /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
fi
cat > /etc/lightdm/lightdm.conf << EOF
[Seat:*]
xserver-command=X -nolisten tcp
autologin-user=kiosk
autologin-session=openbox
EOF

# create autostart
if [ -e "/home/kiosk/.config/openbox/autostart" ]; then
    mv /home/kiosk/.config/openbox/autostart /home/kiosk/.config/openbox/autostart.backup
fi
cat > /home/kiosk/.config/openbox/autostart << EOF
#!/bin/bash

KIOSK_URL="https://wallboard.x-onweb.com"

# The original script included 'unclutter -idle 0.1 -grab -root &'.
# We are removing it to keep the mouse visible.

while :
do
    xrandr --auto
    chromium \
        --noerrdialogs \
        --no-memcheck \
        --no-first-run \
        --start-maximized \
        --disable \
        --disable-translate \
        --disable-infobars \
        --disable-suggestions-service \
        --disable-save-password-bubble \
        --disable-session-crashed-bubble \
        --disable-web-security \
        --disable-features=VizDisplayCompositor \
        --disable-dev-shm-usage \
        --disable-gpu \
        --disable-software-rasterizer \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        --disable-field-trial-config \
        --disable-ipc-flooding-protection \
        --no-sandbox \
        --user-data-dir=/home/kiosk/.config/chromium-kiosk \
        --kiosk $KIOSK_URL
    sleep 5
done &
EOF

echo "Done!"