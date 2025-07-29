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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

echo "Running as root - proceeding with user/group creation..."

# Install required packages for user/group management
echo "Installing required packages for user/group management..."
apt-get install -y adduser passwd

# create group (Debian-recommended approach)
GROUP_CREATED=false
echo "Attempting to create kiosk group..."

if command -v addgroup >/dev/null 2>&1; then
    echo "Found addgroup command, attempting to create group..."
    # Use Debian's recommended addgroup command
    if addgroup --system kiosk 2>&1; then
        echo "Group kiosk created successfully with addgroup"
        GROUP_CREATED=true
    elif getent group kiosk >/dev/null 2>&1; then
        echo "Group kiosk already exists"
        GROUP_CREATED=true
    else
        echo "Failed to create group kiosk with addgroup"
    fi
elif command -v groupadd >/dev/null 2>&1; then
    echo "Found groupadd command, attempting to create group..."
    # Fallback to low-level groupadd command
    if groupadd -f kiosk 2>&1; then
        echo "Group kiosk created successfully with groupadd"
        GROUP_CREATED=true
    elif getent group kiosk >/dev/null 2>&1; then
        echo "Group kiosk already exists"
        GROUP_CREATED=true
    else
        echo "Failed to create group kiosk with groupadd"
    fi
else
    echo "Neither addgroup nor groupadd commands found, attempting to install..."
    apt-get install -y passwd
    if command -v groupadd >/dev/null 2>&1; then
        echo "groupadd command now available after package installation"
        if groupadd -f kiosk 2>&1; then
            echo "Group kiosk created successfully with groupadd"
            GROUP_CREATED=true
        elif getent group kiosk >/dev/null 2>&1; then
            echo "Group kiosk already exists"
            GROUP_CREATED=true
        else
            echo "Failed to create group kiosk with groupadd"
        fi
    else
        echo "ERROR: Could not install or find group creation commands"
        exit 1
    fi
fi

if [ "$GROUP_CREATED" = false ]; then
    echo "ERROR: Could not create kiosk group. Manual intervention required."
    exit 1
fi

# create user if not exists (Debian-recommended approach)
if id -u kiosk &>/dev/null; then
    echo "User kiosk already exists"
else
    echo "Attempting to create kiosk user..."
    USER_CREATED=false
    if command -v adduser >/dev/null 2>&1; then
        echo "Found adduser command, attempting to create user..."
        # Use Debian's recommended adduser command
        if adduser --system --group --home /home/kiosk --shell /bin/bash kiosk 2>&1; then
            echo "User kiosk created successfully with adduser"
            USER_CREATED=true
        else
            echo "Failed to create user kiosk with adduser"
        fi
    elif command -v useradd >/dev/null 2>&1; then
        echo "Found useradd command, attempting to create user..."
        # Fallback to low-level useradd command
        if useradd -m kiosk -g kiosk -s /bin/bash 2>&1; then
            echo "User kiosk created successfully with useradd"
            USER_CREATED=true
        else
            echo "Failed to create user kiosk with useradd"
        fi
    else
        echo "Neither adduser nor useradd commands found, attempting to install..."
        apt-get install -y passwd
        if command -v useradd >/dev/null 2>&1; then
            echo "useradd command now available after package installation"
            if useradd -m kiosk -g kiosk -s /bin/bash 2>&1; then
                echo "User kiosk created successfully with useradd"
                USER_CREATED=true
            else
                echo "Failed to create user kiosk with useradd"
            fi
        else
            echo "ERROR: Could not install or find user creation commands"
            exit 1
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
echo "Setting ownership of /home/kiosk to kiosk:kiosk..."
if chown -R kiosk:kiosk /home/kiosk 2>&1; then
    echo "Ownership set successfully"
else
    echo "WARNING: Could not set ownership of /home/kiosk - continuing anyway"
    echo "This may cause permission issues later"
fi

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