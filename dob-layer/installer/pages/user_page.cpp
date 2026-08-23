#include "user_page.h"

#include <QCheckBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>

UserPage::UserPage(InstallConfig& config, QWidget* parent)
    : QWizardPage(parent)
    , m_config(config)
    , m_confirmEdit(nullptr)
{
    setTitle("User Account");
    setSubTitle("Create the primary user and set the system hostname.");

    auto* layout = new QFormLayout(this);

    auto* nameEdit = new QLineEdit(this);
    nameEdit->setText(m_config.userName);
    connect(nameEdit, &QLineEdit::textChanged,
            this, [this](const QString& t) { m_config.userName = t; });
    layout->addRow("User name:", nameEdit);

    auto* pwEdit = new QLineEdit(this);
    pwEdit->setEchoMode(QLineEdit::Password);
    pwEdit->setText(m_config.password);
    connect(pwEdit, &QLineEdit::textChanged,
            this, [this](const QString& t) { m_config.password = t; });
    layout->addRow("Password:", pwEdit);

    m_confirmEdit = new QLineEdit(this);
    m_confirmEdit->setEchoMode(QLineEdit::Password);
    layout->addRow("Confirm password:", m_confirmEdit);

    auto* hostEdit = new QLineEdit(this);
    hostEdit->setText(m_config.hostname);
    connect(hostEdit, &QLineEdit::textChanged,
            this, [this](const QString& t) { m_config.hostname = t; });
    layout->addRow("Hostname:", hostEdit);

    auto* autologin = new QCheckBox("Automatically log in this user", this);
    autologin->setChecked(m_config.autologin);
    connect(autologin, &QCheckBox::toggled,
            this, [this](bool on) { m_config.autologin = on; });
    layout->addRow(autologin);

    setLayout(layout);
}

int UserPage::nextId() const
{
    return Page_Summary;
}

bool UserPage::validatePage()
{
    return !m_config.userName.isEmpty() &&
           m_config.password == m_confirmEdit->text();
}
