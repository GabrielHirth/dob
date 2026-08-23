#include "summary_page.h"

#include <QFormLayout>
#include <QLabel>
#include <QVBoxLayout>
#include <QPushButton>
#include <QMessageBox>
#include <QFile>
#include <QTextStream>

#include "engine/install_engine.h"

SummaryPage::SummaryPage(InstallConfig& config, QWidget* parent)
    : QWizardPage(parent)
    , m_config(config)
{
    setTitle("Summary");
    setSubTitle("Review your choices before installing.");
}

void SummaryPage::initializePage()
{
    auto* layout = new QVBoxLayout(this);

    // Summary form
    auto* formLayout = new QFormLayout();
    formLayout->addRow("Language:", new QLabel(m_config.language, this));
    formLayout->addRow("Keyboard:", new QLabel(m_config.keymap, this));
    formLayout->addRow("Disk target:", new QLabel(m_config.diskTarget, this));
    formLayout->addRow("File system:",
                       new QLabel(m_config.fsType == InstallConfig::ZFS
                                      ? QString("ZFS")
                                      : QString("UFS"),
                                  this));
    formLayout->addRow("User:", new QLabel(m_config.userName, this));
    formLayout->addRow("Hostname:", new QLabel(m_config.hostname, this));
    formLayout->addRow("Autologin:",
                       new QLabel(m_config.autologin ? QString("yes") : QString("no"),
                                  this));

    layout->addLayout(formLayout);

    // Install button
    m_installButton = new QPushButton("Install", this);
    m_installButton->setMinimumHeight(40);
    connect(m_installButton, &QPushButton::clicked, this, &SummaryPage::onInstallClicked);
    layout->addWidget(m_installButton);

    setLayout(layout);
}

bool SummaryPage::validatePage()
{
    return true;
}

void SummaryPage::onInstallClicked()
{
    m_installButton->setEnabled(false);
    m_installButton->setText("Installing...");

    InstallEngine engine;

    try {
        bool success = engine.apply(m_config);
        if (success) {
            QMessageBox::information(this, "Installation Complete",
                                     "DOB has been successfully installed!");
            // Could call QWizard::accept() here or let user click Finish
        }
    } catch (const std::exception& e) {
        // Read dob-install.log for details
        QString details = e.what();
        QFile logFile("dob-install.log");
        if (logFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&logFile);
            details = in.readAll();
            logFile.close();
        }
        QMessageBox::critical(this, "Installation Failed",
                              "Installation failed:\n" + details);
    }

    m_installButton->setEnabled(true);
    m_installButton->setText("Install");
}
