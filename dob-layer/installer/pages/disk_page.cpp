#include "disk_page.h"

#include <QComboBox>
#include <QGroupBox>
#include <QRadioButton>
#include <QVBoxLayout>
#include <QLabel>

DiskPage::DiskPage(InstallConfig& config, QWidget* parent)
    : QWizardPage(parent)
    , m_config(config)
{
    setTitle("Disk Setup");
    setSubTitle("Guided installation: the entire selected disk will be used.");

    auto* layout = new QVBoxLayout(this);

    auto* group = new QGroupBox("Use entire disk", this);
    auto* groupLayout = new QVBoxLayout(group);

    auto* zfs = new QRadioButton("ZFS", group);
    auto* ufs = new QRadioButton("UFS", group);
    zfs->setChecked(m_config.fsType == InstallConfig::ZFS);
    ufs->setChecked(m_config.fsType == InstallConfig::UFS);
    connect(zfs, &QRadioButton::toggled, this, [this](bool on) {
        if (on) m_config.fsType = InstallConfig::ZFS;
    });
    connect(ufs, &QRadioButton::toggled, this, [this](bool on) {
        if (on) m_config.fsType = InstallConfig::UFS;
    });
    groupLayout->addWidget(zfs);
    groupLayout->addWidget(ufs);

    auto* targetCombo = new QComboBox(group);
    targetCombo->setEditable(false);

    // Static list; real device enumeration behind a guarded build flag.
#ifdef DOB_REAL_DISK
    // TODO(Task 9): enumerate actual disks via geom/camcontrol.
#else
    targetCombo->addItems(QStringList() << "/dev/ada0" << "/dev/da0");
#endif

    if (!m_config.diskTarget.isEmpty() &&
        targetCombo->findText(m_config.diskTarget) != -1) {
        targetCombo->setCurrentText(m_config.diskTarget);
    } else if (!targetCombo->currentText().isEmpty()) {
        m_config.diskTarget = targetCombo->currentText();
    }
    connect(targetCombo, &QComboBox::currentTextChanged,
            this, [this](const QString& text) { m_config.diskTarget = text; });
    groupLayout->addWidget(targetCombo);

    group->setLayout(groupLayout);
    layout->addWidget(group);

    auto* warning = new QLabel("This will erase ALL data on the selected disk.", this);
    warning->setStyleSheet("QLabel { color: #C0102A; font-weight: bold; }");
    layout->addWidget(warning);

    layout->addStretch(1);
}

int DiskPage::nextId() const
{
    return Page_User;
}

bool DiskPage::validatePage()
{
    return !m_config.diskTarget.isEmpty();
}
