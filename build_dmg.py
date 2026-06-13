#!/usr/bin/env python3
"""
DMG Builder for YouTube Downloader
Automates building a macOS DMG installer with custom icon
"""

import os
import subprocess
import shutil
import sys
from pathlib import Path

class DMGBuilder:
    def __init__(self):
        self.app_name = "YouTubeDownloader"
        self.main_script = "main.py"
        self.icon_file = "downloading.icns"
        self.volume_name = "YouTubeDownloader Installer"
        self.dmg_name = f"{self.app_name}.dmg"
        self.dist_path = Path("dist")
        self.app_bundle_path = self.dist_path / f"{self.app_name}.app"
        self.dmg_temp = Path("dmg_temp")
        
    def log(self, message: str, emoji: str = ""):
        """Print formatted log message"""
        print(f"{emoji} {message}")
    
    def run_command(self, command: list, description: str) -> bool:
        """Run shell command and handle errors"""
        try:
            self.log(description, "⏳")
            subprocess.run(command, check=True, capture_output=False)
            return True
        except subprocess.CalledProcessError as e:
            self.log(f"Error: {e}", "❌")
            return False
    
    def clean_previous_builds(self):
        """Remove previous build artifacts"""
        self.log("Cleaning up previous builds...", "🧹")
        for path in [self.dist_path, self.dmg_temp, Path(self.dmg_name), Path("build")]:
            if path.exists():
                if path.is_dir():
                    shutil.rmtree(path)
                else:
                    path.unlink()
        
        # Remove .spec files
        for spec_file in Path(".").glob("*.spec"):
            spec_file.unlink()
    
    def build_app_bundle(self):
        """Build macOS app bundle with PyInstaller"""
        self.log("Building app with PyInstaller...", "🔨")
        
        command = [
            "pyinstaller",
            "--windowed",
            "--onefile",
            f"--name={self.app_name}",
            f"--icon={self.icon_file}",
            self.main_script
        ]
        
        if not self.run_command(command, "Running PyInstaller..."):
            return False
        
        self.log(f"App bundle created at {self.app_bundle_path}", "✅")
        return True
    
    def copy_icon_to_bundle(self):
        """Copy icon to app bundle resources"""
        self.log("Copying icon to app bundle...", "📦")
        
        resources_path = self.app_bundle_path / "Contents" / "Resources"
        resources_path.mkdir(parents=True, exist_ok=True)
        
        icon_dest = resources_path / self.icon_file
        if Path(self.icon_file).exists():
            shutil.copy(self.icon_file, icon_dest)
            self.log(f"Icon copied to {icon_dest}", "✅")
            return True
        else:
            self.log(f"Icon file not found: {self.icon_file}", "❌")
            return False
    
    def create_dmg_staging(self):
        """Create DMG staging directory"""
        self.log("Creating DMG staging directory...", "📁")
        
        if self.dmg_temp.exists():
            shutil.rmtree(self.dmg_temp)
        
        self.dmg_temp.mkdir()
        
        # Copy app
        app_dest = self.dmg_temp / self.app_bundle_path.name
        shutil.copytree(self.app_bundle_path, app_dest)
        
        # Create Applications symlink
        applications_link = self.dmg_temp / "Applications"
        if not applications_link.exists():
            os.symlink("/Applications", applications_link)
        
        self.log("DMG staging directory created", "✅")
        return True
    
    def set_dmg_icon(self):
        """Set custom icon for DMG volume"""
        self.log("Setting DMG volume icon...", "🎨")
        
        volume_icon = self.dmg_temp / ".VolumeIcon.icns"
        if Path(self.icon_file).exists():
            shutil.copy(self.icon_file, volume_icon)
            
            # Hide icon file
            try:
                os.chmod(volume_icon, os.stat(volume_icon).st_mode | 0o200)
                subprocess.run(["chflags", "hidden", str(volume_icon)], check=False)
            except Exception as e:
                self.log(f"Warning: Could not hide icon file: {e}", "⚠️")
            
            # Try to use SetFile if available
            try:
                subprocess.run(["SetFile", "-a", "C", str(self.dmg_temp)], 
                             check=False, capture_output=True)
                self.log("SetFile icon assignment complete", "✅")
            except Exception:
                self.log("SetFile not available. Install Xcode CLI tools with: xcode-select --install", "⚠️")
            
            return True
        else:
            self.log(f"Icon file not found: {self.icon_file}", "❌")
            return False
    
    def create_dmg(self):
        """Create the final compressed DMG"""
        self.log("Creating compressed DMG...", "💾")
        
        command = [
            "hdiutil",
            "create",
            "-volname", self.volume_name,
            "-srcfolder", str(self.dmg_temp),
            "-ov",
            "-format", "UDZO",
            self.dmg_name
        ]
        
        return self.run_command(command, "Running hdiutil...")
    
    def cleanup(self):
        """Remove temporary build files"""
        self.log("Cleaning up temporary files...", "🧹")
        
        if self.dmg_temp.exists():
            shutil.rmtree(self.dmg_temp)
        
        if self.dist_path.exists():
            shutil.rmtree(self.dist_path)
        
        if Path("build").exists():
            shutil.rmtree("build")
        
        for spec_file in Path(".").glob("*.spec"):
            spec_file.unlink()
    
    def print_summary(self):
        """Print build summary"""
        dmg_path = Path(self.dmg_name)
        if dmg_path.exists():
            file_size = os.path.getsize(dmg_path) / (1024 * 1024)
            print("\n" + "="*50)
            print("✨ Success! DMG created successfully")
            print("="*50)
            print(f"📊 File name: {self.dmg_name}")
            print(f"📈 File size: {file_size:.2f} MB")
            print(f"📍 Location: {dmg_path.absolute()}")
            print("="*50 + "\n")
    
    def build(self):
        """Execute the full build process"""
        print("\n🚀 Starting macOS DMG build process...\n")
        
        steps = [
            ("clean_previous_builds", self.clean_previous_builds),
            ("build_app_bundle", self.build_app_bundle),
            ("copy_icon_to_bundle", self.copy_icon_to_bundle),
            ("create_dmg_staging", self.create_dmg_staging),
            ("set_dmg_icon", self.set_dmg_icon),
            ("create_dmg", self.create_dmg),
            ("cleanup", self.cleanup),
        ]
        
        for step_name, step_func in steps:
            try:
                if not step_func():
                    self.log(f"Build failed at step: {step_name}", "❌")
                    return False
            except Exception as e:
                self.log(f"Error in {step_name}: {e}", "❌")
                return False
        
        self.print_summary()
        return True

if __name__ == "__main__":
    builder = DMGBuilder()
    success = builder.build()
    sys.exit(0 if success else 1)
