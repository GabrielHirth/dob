#ifndef DOB_INSTALLER_ENGINE_PLAN_INSTALL_H
#define DOB_INSTALLER_ENGINE_PLAN_INSTALL_H

#include <vector>
#include "../config.h"

enum class StepKind { CloneRoot, ApplyLayer, CreateUsers, WriteBoot, Done };

struct InstallStep {
    StepKind kind;
    QString detail;
};

std::vector<InstallStep> planInstall(const InstallConfig& c);

#endif // DOB_INSTALLER_ENGINE_PLAN_INSTALL_H