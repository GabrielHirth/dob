#ifndef DOB_INSTALLER_CONFIG_H
#define DOB_INSTALLER_CONFIG_H

#include <QString>

// InstallConfig holds the user's installation choices.
// Consumed by installer pages (Tasks 7-9).
struct InstallConfig {
    enum FsType { ZFS, UFS };

    QString language;    // default "en"
    QString keymap;      // default "us"
    QString diskTarget;  // device path, e.g. /dev/ada0
    FsType fsType = ZFS; // ZFS default
    QString userName;
    QString password;
    QString hostname;
    bool autologin = false;

    InstallConfig();
};

#endif // DOB_INSTALLER_CONFIG_H
