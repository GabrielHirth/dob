#ifndef DOB_INSTALLER_PAGES_USER_PAGE_H
#define DOB_INSTALLER_PAGES_USER_PAGE_H

#include <QWizardPage>

#include <QLineEdit>

#include "config.h"

// UserPage: primary user account, password + confirm, hostname, autologin.
// Requires a non-empty user name and matching passwords.
class UserPage : public QWizardPage {
    Q_OBJECT

public:
    explicit UserPage(InstallConfig& config, QWidget* parent = nullptr);

    int nextId() const override;
    bool validatePage() override;

private:
    InstallConfig& m_config;
    QLineEdit* m_confirmEdit;
};

#endif // DOB_INSTALLER_PAGES_USER_PAGE_H
