#include <QApplication>

#include "installer.h"

int main(int argc, char** argv) {
    QApplication app(argc, argv);
    Installer w;
    w.setWindowTitle("DOB Installer");
    w.show();
    return app.exec();
}
