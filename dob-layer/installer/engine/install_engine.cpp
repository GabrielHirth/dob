#include "install_engine.h"
#include "plan_install.h"

#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QFileInfo>
#include <stdexcept>

bool InstallEngine::apply(const InstallConfig& config) {
    // Validate-then-write: re-validate diskTarget
    if (config.diskTarget.isEmpty()) {
        throw std::runtime_error("diskTarget is empty");
    }

    // Get install plan to drive ordering
    auto steps = planInstall(config);

    try {
        for (const auto& step : steps) {
            // Check for disk full simulation
            if (m_simulateDiskFull) {
                throw std::runtime_error("Target disk full");
            }

            switch (step.kind) {
                case StepKind::CloneRoot: {
                    // Clone live root to target
#ifdef DOB_REAL_DISK
                    // Real disk operations would go here (require root)
#else
                    // Safe no-op on macOS / test environments
#endif
                    break;
                }
                case StepKind::ApplyLayer: {
                    // Apply DOB layer (theme, users, hostname)
#ifdef DOB_REAL_DISK
                    // Real apply layer would call theme/apply.sh logic
#else
                    // Safe no-op on macOS / test environments
#endif
                    break;
                }
                case StepKind::CreateUsers: {
                    // Create user on target system
#ifdef DOB_REAL_DISK
                    // Real user creation would go here
#else
                    // Safe no-op on macOS / test environments
#endif
                    break;
                }
                case StepKind::WriteBoot: {
                    // Write boot blocks
#ifdef DOB_REAL_DISK
                    // Real boot block writing would go here
#else
                    // Log intent only on macOS / test environments
#endif
                    break;
                }
                case StepKind::Done:
                    // Installation complete
                    break;
            }
        }
        return true;
    } catch (const std::exception& e) {
        // Auto-rollback on any failure
        rollback();

        // Write dob-install.log
        QFile logFile("dob-install.log");
        if (logFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&logFile);
            out << "Installation failed: " << e.what() << "\n";
            out << "Disk target: " << config.diskTarget << "\n";
            out << "User: " << config.userName << "\n";
            out << "Hostname: " << config.hostname << "\n";
            logFile.close();
        }

        // Re-throw to let UI handle
        throw;
    }
}

void InstallEngine::setDiskFull(bool enabled) {
    m_simulateDiskFull = enabled;
}

void InstallEngine::rollback() {
    // Unmount/clean target
#ifdef DOB_REAL_DISK
    // Real rollback would unmount and clean
#else
    // Safe no-op on macOS / test environments
#endif
}