#!/bin/bash

VM_USER="jamie"
VM_IP="192.168.1.124"
RM_IP="192.168.1.112"
READECK_API_KEY="AD8mpt7vRfjDD9MQdwvb5N7nLSYSs4SkyXG8jBC5MgQEyjCk"
READECK_URL="https://readeck.helios.red"

echo "============================="
echo "Building application..."
echo "============================="

echo "Choose build type:"
echo "1) Local build (for testing on this machine)"
echo "2) Remote build (for reMarkable device - aarch64)"
read -p "Enter choice (1 or 2): " choice

# Clean up previous builds
echo "Cleaning up previous builds..."
rm -rf dist-local dist-rm qml_output

# Build front-end 
echo "Building frontend..."
mkdir qml_output
(
    cd qml-src
    cp manifest.json ../qml_output/
    /usr/lib/qt6/libexec/rcc --binary -o ../qml_output/resources.rcc application.qrc
)

echo "==========================="
echo "Compiling backend python..."
echo "==========================="
echo "Removing previous build dirs (seems to work better this way)"
rm -rf ./python-src/build
rm -rf ./python-src/dist

if [ "$choice" = "1" ]; then
    echo "Building locally..."

    # Create dist-local structure
    mkdir -p dist-local/rm-readeck/backend

    # Build backend locally
    cd python-src
    source venv/bin/activate
    pyinstaller --onedir --noconfirm --name entry main.py

    # Copy backend to dist-local
    cp -r ./dist/entry/* ../dist-local/rm-readeck/backend/
    cd ..

    # Copy frontend files to dist-local
    cp qml_output/manifest.json dist-local/rm-readeck/
    cp qml_output/resources.rcc dist-local/rm-readeck/
    cp qml-src/icon.png dist-local/rm-readeck/

    # Install to appload
    echo "Installing to appload..."
    rm -rf ./rm-appload/applications_root/rm-readeck
    cp -r dist-local/rm-readeck ./rm-appload/applications_root/

elif [ "$choice" = "2" ]; then
    echo "Building remotely on $VM_IP..."

    # Create dist-rm structure
    mkdir -p dist-rm/rm-readeck/backend

    # Clean VM
    ssh $VM_USER@$VM_IP "rm -rf python-src"
    #echo "Previous source dirs have been removed"

    # Send source code to VM (excluding venv and cache)
    echo "Sending source code to VM..."
    rsync -av --exclude='venv/' --exclude='__pycache__/' --exclude='dist/' python-src/ $VM_USER@$VM_IP:~/python-src/

    # Set up venv and install dependencies on VM
    echo "Setting up environment on VM..."
    ssh $VM_USER@$VM_IP "
        cd ~/python-src && 
        python3 -m venv venv && 
        source venv/bin/activate && 
        pip install --upgrade pip &&
        pip install pyinstaller requests
    "

    # Build on VM
    echo "Building on VM..."
    ssh $VM_USER@$VM_IP "cd ~/python-src && source venv/bin/activate && pip install -r requirements.txt && pyinstaller --onedir --noconfirm --name entry main.py"

    # Fetch built backend from VM
    echo "Fetching built backend from VM..."
    rsync -av $VM_USER@$VM_IP:~/python-src/dist/entry/ dist-rm/rm-readeck/backend/

    # Copy frontend files to dist-rm
    cp qml_output/manifest.json dist-rm/rm-readeck/
    cp qml_output/resources.rcc dist-rm/rm-readeck/
    cp qml-src/icon.png dist-rm/rm-readeck/

    # Ask if user wants to deploy to reMarkable
    echo ""
    echo "=========================================="
    read -p "Deploy to reMarkable device? (y/n): " deploy_choice

    if [ "$deploy_choice" = "y" ] || [ "$deploy_choice" = "Y" ]; then
        echo "Deploying to reMarkable at $RM_IP..."

        # Create tar archive
        echo "Creating deployment archive..."
        cd dist-rm
        tar -czf rm-readeck.tar.gz rm-readeck/
        cd ..

        # Send to reMarkable and deploy
        echo "Sending to reMarkable..."
        scp dist-rm/rm-readeck.tar.gz root@$RM_IP:~/

        echo "Installing on reMarkable..."
        ssh root@$RM_IP "
            cd ~/xovi/exthome/appload/ &&
            rm -rf rm-readeck &&
            tar -xzf ~/rm-readeck.tar.gz &&
            rm ~/rm-readeck.tar.gz
        "

        # Copy config file to reMarkable
        echo "Creating and copying config file..."
        cat > /tmp/rm-readeck-config << EOF
READECK_URL=$READECK_URL
READECK_API_KEY=$READECK_API_KEY
EOF

        scp /tmp/rm-readeck-config root@$RM_IP:~/.rm-readeck
        rm /tmp/rm-readeck-config

        echo "Deployment complete!"
        echo "Config file created at ~/.rm-readeck with:"
        echo "  READECK_URL=$READECK_URL"
        echo "  READECK_API_KEY=$READECK_API_KEY"

        # Clean up local tar file
        rm -f dist-rm/rm-readeck.tar.gz
    else
        echo "Skipping deployment to reMarkable."
    fi

else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Clean up temp files
rm -rf qml_output

echo "=========================================="
if [ "$choice" = "1" ]; then
    echo "Local build complete!"
    echo "Built files are in: dist-local/rm-readeck/"
    echo "Installed to appload. Run appload to test."
else
    echo "Remote build complete!"
    echo "Built files are in: dist-rm/rm-readeck/"
    if [ "$deploy_choice" = "y" ] || [ "$deploy_choice" = "Y" ]; then
        echo "Successfully deployed to reMarkable device."
    else
        echo "Ready to transfer to reMarkable device manually."
    fi
fi
echo "=========================================="
