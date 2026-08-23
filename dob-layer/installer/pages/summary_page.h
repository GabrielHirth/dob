#ifndef DOB_INSTALLER_PAGES_SUMMARY_PAGE_H
#define DOB_INSTALLER_PAGES_SUMMARY_PAGE_H

#include <QWizardPage>
#include <QPushButton>
#include <QMessageBox>

#include "config.h"

class InstallEngine;

// SummaryPage: read-only review of the installation choices.
// Triggers installation on button click.
class SummaryPage : public QWizardPage {
    Q_OBJECT

public:
    explicit SummaryPage(InstallConfig& config, QWidget* parent = nullptr);

    void initializePage() override;
    bool validatePage() override;

private slots:
    void onInstallClicked();

private:
    InstallConfig& m_config;
    QPushButton* m_installButton = nullptr;
};

#endif // DOB_INSTALLER_PAGES_SUMMARY_PAGE_H
