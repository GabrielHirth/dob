#include "welcome_page.h"

#include <QComboBox>
#include <QGridLayout>
#include <QLabel>
#include <QPixmap>
#include <QVBoxLayout>

WelcomePage::WelcomePage(InstallConfig& config, QWidget* parent)
    : QWizardPage(parent)
    , m_config(config)
{
    setTitle("Welcome to DOB");
    setSubTitle("Select your language and keyboard layout to begin.");

    auto* layout = new QVBoxLayout(this);

    auto* logo = new QLabel(this);
    logo->setPixmap(QPixmap(":/branding/branding.svg"));
    logo->setAlignment(Qt::AlignCenter);
    layout->addWidget(logo);

    auto* form = new QGridLayout();

    form->addWidget(new QLabel("Language:", this), 0, 0);

    auto* languageCombo = new QComboBox(this);
    languageCombo->addItem("English", "en");
    languageCombo->addItem("Deutsch", "de");
    languageCombo->addItem("Français", "fr");
    languageCombo->addItem("Español", "es");
    languageCombo->setCurrentIndex(languageCombo->findData(m_config.language));
    connect(languageCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, [this, languageCombo](int) {
                m_config.language = languageCombo->currentData().toString();
            });
    form->addWidget(languageCombo, 0, 1);

    form->addWidget(new QLabel("Keyboard:", this), 1, 0);

    auto* keymapCombo = new QComboBox(this);
    keymapCombo->addItem("us");
    keymapCombo->addItem("de");
    keymapCombo->addItem("fr");
    keymapCombo->addItem("es");
    keymapCombo->addItem("gb");
    keymapCombo->setCurrentText(m_config.keymap);
    connect(keymapCombo, &QComboBox::currentTextChanged,
            this, [this](const QString& text) { m_config.keymap = text; });
    form->addWidget(keymapCombo, 1, 1);

    layout->addLayout(form);
    layout->addStretch(1);
}

int WelcomePage::nextId() const
{
    return Page_Disk;
}

bool WelcomePage::validatePage()
{
    return true;
}
