#ifndef DOB_INSTALLER_PAGES_DISK_PAGE_H
#define DOB_INSTALLER_PAGES_DISK_PAGE_H

#include <QWizardPage>

#include "config.h"

// DiskPage: guided "use entire disk" install with ZFS/UFS choice.
// No custom partition editor. Requires a non-empty disk target.
class DiskPage : public QWizardPage {
    Q_OBJECT

public:
    explicit DiskPage(InstallConfig& config, QWidget* parent = nullptr);

    int nextId() const override;
    bool validatePage() override;

private:
    InstallConfig& m_config;
};

#endif // DOB_INSTALLER_PAGES_DISK_PAGE_H
