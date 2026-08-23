#ifndef DOB_INSTALLER_PAGES_SUMMARY_PAGE_H
#define DOB_INSTALLER_PAGES_SUMMARY_PAGE_H

#include <QWizardPage>

#include "config.h"

// SummaryPage: read-only review of the installation choices.
// No inputs; validatePage() returns true (review only).
class SummaryPage : public QWizardPage {
    Q_OBJECT

public:
    explicit SummaryPage(InstallConfig& config, QWidget* parent = nullptr);

    void initializePage() override;
    bool validatePage() override;

private:
    InstallConfig& m_config;
};

#endif // DOB_INSTALLER_PAGES_SUMMARY_PAGE_H
