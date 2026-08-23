#include "installer.h"

#include <QPalette>
#include <QStyleFactory>

Installer::Installer(QWidget* parent)
    : QWizard(parent)
{
    setWindowTitle("DOB Installer");
    setWizardStyle(QWizard::ModernStyle);
    setOption(HaveFinishButtonOnEarlyPages, true);

    // DOB-styled palette: red-tinted Fruitiger Aero accent.
    QPalette pal = palette();
    const QColor accent("#C0102A");
    const QColor highlight("#E63950");
    const QColor deep("#7A0A1E");
    pal.setColor(QPalette::Highlight, accent);
    pal.setColor(QPalette::HighlightedText, Qt::white);
    pal.setColor(QPalette::Button, QColor("#F2F2F4"));
    setPalette(pal);

    setStyleSheet(
        "QPushButton {"
        "  background-color: #C0102A;"
        "  color: #FFFFFF;"
        "  border-radius: 6px;"
        "  padding: 6px 16px;"
        "  font-weight: bold;"
        "}"
        "QPushButton:hover { background-color: #E63950; }"
        "QPushButton:disabled { background-color: #B89CA2; }"
        "QWizard { background-color: #FBFBFC; }"
        "QLabel { color: #7A0A1E; }"
    );
}
