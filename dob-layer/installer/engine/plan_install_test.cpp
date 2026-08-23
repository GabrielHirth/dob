#include "plan_install.h"
#include <cassert>

int main() {
    InstallConfig c;
    c.diskTarget = "/dev/ada0";
    c.userName = "alice";
    c.hostname = "dobbox";
    auto steps = planInstall(c);
    assert(!steps.empty());
    assert(steps.front().kind == StepKind::CloneRoot);   // clones live root first
    assert(steps.back().kind == StepKind::Done);
    bool hasBoot = false;
    for (auto& s : steps) if (s.kind == StepKind::WriteBoot) hasBoot = true;
    assert(hasBoot);
    return 0;
}