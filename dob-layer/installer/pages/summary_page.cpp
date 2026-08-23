#include "summary_page.h"

#include <QFormLayout>
#include <QLabel>

SummaryPage::SummaryPage(InstallConfig& config, QWidget* parent)
    : QWizardPage(parent)
    , m_config(config)
{
    setTitle("Summary");
    setSubTitle("Review your choices before installing.");
}

void SummaryPage::initializePage()
{
    auto* layout = new QFormLayout(this);

    layout->addRow("Language:", new QLabel(m_config.language, this));
    layout->addRow("Keyboard:", new QLabel(m_config.keymap, this));
    layout->addRow("Disk target:", new QLabel(m_config.diskTarget, this));
    layout->addRow("File system:",
                   new QLabel(m_config.fsType == InstallConfig::ZFS
                                  ? QString("ZFS")
                                  : QString("UFS"),
                              this));
    layout->addRow("User:", new QLabel(m_config.userName, this));
    layout->addRow("Hostname:", new QLabel(m_config.hostname, this));
    layout->addRow("Autologin:",
                   new QLabel(m_config.autologin ? QString("yes") : QString("no"),
                              this));

    setLayout(layout);
}

bool SummaryPage::validatePage()
{
    return true;
}
