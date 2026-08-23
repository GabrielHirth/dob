#include "plan_install.h"

std::vector<InstallStep> planInstall(const InstallConfig& c) {
    std::vector<InstallStep> v;
    v.push_back({StepKind::CloneRoot, QString("Clone live root to ") + c.diskTarget});
    v.push_back({StepKind::ApplyLayer, QString("Apply DOB layer (theme, users, hostname)")});
    v.push_back({StepKind::CreateUsers, QString("Create user ") + c.userName + " on " + c.hostname});
    v.push_back({StepKind::WriteBoot, QString("Write boot blocks (") +
                 QString(c.fsType == InstallConfig::ZFS ? "ZFS" : "UFS") + ")"});
    v.push_back({StepKind::Done, QString("Installation complete")});
    return v;
}