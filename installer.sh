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
GROUP_CREATED=false
if command -v groupadd >/dev/null 2>&1; then
    if groupadd -f kiosk 2>/dev/null; then
        echo "Group kiosk created successfully"
        GROUP_CREATED=true
    elif getent group kiosk >/dev/null 2>&1; then
        echo "Group kiosk already exists"
        GROUP_CREATED=true
    else
        echo "Failed to create group kiosk with groupadd"
    fi
fi

if [ "$GROUP_CREATED" = false ]; then
    echo "Trying addgroup as alternative..."
    if command -v addgroup >/dev/null 2>&1; then
        if addgroup --system kiosk 2>/dev/null; then
            echo "Group kiosk created successfully with addgroup"
            GROUP_CREATED=true
        elif getent group kiosk >/dev/null 2>&1; then
            echo "Group kiosk already exists"
            GROUP_CREATED=true
        else
            echo "Failed to create group kiosk with addgroup"
        fi
    fi
fi

if [ "$GROUP_CREATED" = false ]; then
    echo "ERROR: Could not create kiosk group. Manual intervention required."
    exit 1
fi

# create user if not exists (handle different systems)
if id -u kiosk &>/dev/null; then
    echo "User kiosk already exists"
else
    USER_CREATED=false
    if command -v useradd >/dev/null 2>&1; then
        if useradd -m kiosk -g kiosk -s /bin/bash 2>/dev/null; then
            echo "User kiosk created successfully"
            USER_CREATED=true
        else
            echo "Failed to create user kiosk with useradd"
        fi
    fi
    
    if [ "$USER_CREATED" = false ] && command -v adduser >/dev/null 2>&1; then
        echo "Trying adduser as alternative..."
        if adduser --system --group --home /home/kiosk --shell /bin/bash kiosk 2>/dev/null; then
            echo "User kiosk created successfully with adduser"
            USER_CREATED=true
        else
            echo "Failed to create user kiosk with adduser"
        fi
    fi
    
    if [ "$USER_CREATED" = false ]; then
        echo "ERROR: Could not create kiosk user. Manual intervention required."
        exit 1
    fi
fi

# verify user and group exist
if ! id -u kiosk &>/dev/null; then
    echo "ERROR: User kiosk does not exist after creation attempts"
    exit 1
fi

if ! getent group kiosk >/dev/null 2>&1; then
    echo "ERROR: Group kiosk does not exist after creation attempts"
    exit 1
fi

echo "User and group verification successful"

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