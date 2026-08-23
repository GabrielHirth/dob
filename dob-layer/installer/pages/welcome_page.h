#ifndef DOB_INSTALLER_PAGES_WELCOME_PAGE_H
#define DOB_INSTALLER_PAGES_WELCOME_PAGE_H

#include <QWizardPage>

#include "config.h"

// WelcomePage: DOB branding + language/keymap selection.
// Defaults (English / us) are always valid, so validatePage() returns true.
class WelcomePage : public QWizardPage {
    Q_OBJECT

public:
    explicit WelcomePage(InstallConfig& config, QWidget* parent = nullptr);

    int nextId() const override;
    bool validatePage() override;

private:
    InstallConfig& m_config;
};

#endif // DOB_INSTALLER_PAGES_WELCOME_PAGE_H
