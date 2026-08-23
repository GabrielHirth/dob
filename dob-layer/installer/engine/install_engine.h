#ifndef DOB_INSTALLER_ENGINE_INSTALL_ENGINE_H
#define DOB_INSTALLER_ENGINE_INSTALL_ENGINE_H

#include <QString>
#include <string>

#include "../config.h"

class InstallEngine {
public:
    bool apply(const InstallConfig& config);
    void setDiskFull(bool enabled);

private:
    void rollback();
    bool m_simulateDiskFull = false;
};

#endif // DOB_INSTALLER_ENGINE_INSTALL_ENGINE_H