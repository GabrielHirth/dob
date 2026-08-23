#ifndef DOB_INSTALLER_INSTALLER_H
#define DOB_INSTALLER_INSTALLER_H

#include <QWizard>

#include "config.h"

// Installer is the branded QWizard window.
// Pages are added in Task 7; for now it constructs an empty,
// DOB-styled window titled "DOB Installer".
class Installer : public QWizard {
    Q_OBJECT

public:
    explicit Installer(QWidget* parent = nullptr);

private:
    InstallConfig m_config;
};

#endif // DOB_INSTALLER_INSTALLER_H
