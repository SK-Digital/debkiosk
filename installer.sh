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

# First check if group already exists
if getent group kiosk >/dev/null 2>&1; then
    echo "Group kiosk already exists"
    GROUP_CREATED=true
else
    # Try addgroup first (Debian recommended)
    if command -v addgroup >/dev/null 2>&1; then
        echo "Found addgroup command, attempting to create group..."
        if addgroup --system kiosk 2>&1; then
            echo "Group kiosk created successfully with addgroup"
            GROUP_CREATED=true
        else
            echo "addgroup failed, trying alternative approach..."
            # Try without --system flag
            if addgroup kiosk 2>&1; then
                echo "Group kiosk created successfully with addgroup (without --system)"
                GROUP_CREATED=true
            else
                echo "addgroup failed completely"
            fi
        fi
    fi
    
    # If addgroup failed or doesn't exist, try groupadd
    if [ "$GROUP_CREATED" = false ] && command -v groupadd >/dev/null 2>&1; then
        echo "Found groupadd command, attempting to create group..."
        if groupadd -f kiosk 2>&1; then
            echo "Group kiosk created successfully with groupadd"
            GROUP_CREATED=true
        else
            echo "groupadd failed"
        fi
    fi
    
    # If both failed, try to install packages and retry
    if [ "$GROUP_CREATED" = false ]; then
        echo "Both addgroup and groupadd failed, attempting to install packages..."
        apt-get update
        apt-get install -y adduser passwd
        sleep 2
        
        # Try addgroup again after package installation
        if command -v addgroup >/dev/null 2>&1; then
            echo "Retrying addgroup after package installation..."
            if addgroup --system kiosk 2>&1; then
                echo "Group kiosk created successfully with addgroup (retry)"
                GROUP_CREATED=true
            elif addgroup kiosk 2>&1; then
                echo "Group kiosk created successfully with addgroup (retry, no --system)"
                GROUP_CREATED=true
            fi
        fi
        
        # Try groupadd again after package installation
        if [ "$GROUP_CREATED" = false ] && command -v groupadd >/dev/null 2>&1; then
            echo "Retrying groupadd after package installation..."
            if groupadd -f kiosk 2>&1; then
                echo "Group kiosk created successfully with groupadd (retry)"
                GROUP_CREATED=true
            fi
        fi
    fi
fi

# Final verification
if [ "$GROUP_CREATED" = false ]; then
    echo "ERROR: Could not create kiosk group after all attempts"
    echo "Manual intervention required. Please run:"
    echo "  sudo addgroup kiosk"
    echo "  or"
    echo "  sudo groupadd kiosk"
    exit 1
fi

# Verify group was actually created
if ! getent group kiosk >/dev/null 2>&1; then
    echo "ERROR: Group kiosk does not exist after creation attempts"
    exit 1
fi

echo "Group creation successful and verified"

# create user if not exists (Debian-recommended approach)
if id -u kiosk &>/dev/null; then
    echo "User kiosk already exists"
else
    echo "Attempting to create kiosk user..."
    USER_CREATED=false
    
    # Try adduser first (Debian recommended)
    if command -v adduser >/dev/null 2>&1; then
        echo "Found adduser command, attempting to create user..."
        if adduser --system --group --home /home/kiosk --shell /bin/bash kiosk 2>&1; then
            echo "User kiosk created successfully with adduser"
            USER_CREATED=true
        else
            echo "adduser failed, trying alternative approach..."
            # Try without --system flag
            if adduser --group --home /home/kiosk --shell /bin/bash kiosk 2>&1; then
                echo "User kiosk created successfully with adduser (without --system)"
                USER_CREATED=true
            else
                echo "adduser failed completely"
            fi
        fi
    fi
    
    # If adduser failed or doesn't exist, try useradd
    if [ "$USER_CREATED" = false ] && command -v useradd >/dev/null 2>&1; then
        echo "Found useradd command, attempting to create user..."
        if useradd -m kiosk -g kiosk -s /bin/bash 2>&1; then
            echo "User kiosk created successfully with useradd"
            USER_CREATED=true
        else
            echo "useradd failed"
        fi
    fi
    
    # If both failed, try to install packages and retry
    if [ "$USER_CREATED" = false ]; then
        echo "Both adduser and useradd failed, attempting to install packages..."
        apt-get update
        apt-get install -y adduser passwd
        sleep 2
        
        # Try adduser again after package installation
        if command -v adduser >/dev/null 2>&1; then
            echo "Retrying adduser after package installation..."
            if adduser --system --group --home /home/kiosk --shell /bin/bash kiosk 2>&1; then
                echo "User kiosk created successfully with adduser (retry)"
                USER_CREATED=true
            elif adduser --group --home /home/kiosk --shell /bin/bash kiosk 2>&1; then
                echo "User kiosk created successfully with adduser (retry, no --system)"
                USER_CREATED=true
            fi
        fi
        
        # Try useradd again after package installation
        if [ "$USER_CREATED" = false ] && command -v useradd >/dev/null 2>&1; then
            echo "Retrying useradd after package installation..."
            if useradd -m kiosk -g kiosk -s /bin/bash 2>&1; then
                echo "User kiosk created successfully with useradd (retry)"
                USER_CREATED=true
            fi
        fi
    fi
    
    if [ "$USER_CREATED" = false ]; then
        echo "ERROR: Could not create kiosk user after all attempts"
        echo "Manual intervention required. Please run:"
        echo "  sudo adduser --system --group kiosk"
        echo "  or"
        echo "  sudo useradd -m kiosk -g kiosk"
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