#include "lookup_suffix.hpp"

#include <iostream>
#include <stdexcept>

void check(const std::vector<int>& ctx, int limit, int first, int sources, int pos, const std::vector<int>& expected) {
    int match = -2;
    auto result = fnx::select_lookup_drafts(ctx, limit, first, sources, 999, &match);
    if (match != pos || result != expected) throw std::runtime_error("unexpected lookup drafts or match position");
}

int main() {
    const std::vector<int> repeated{8,1,2,3,4,5,6,7,9,1,2,3,4,7,8,1,2,3};
    check(repeated, 15, 4, 1, 9, {4,7,8});
    check(repeated, 15, 4, 4, 1, {4,5,6,7});
    check(repeated, 3, -1, 4, 9, {4,7,8});
    check({1,2,3,7,0,1,2,3,8,0,1,2,3}, 4, 7, 1, -1, {});
    check({1,2,3,7,0,1,2,3,8,0,1,2,3}, 4, 7, 4, 0, {7,0,1});
    check({1,2,3,7,999,5,1,2,3}, 3, 7, 1, 0, {7});
    check({1,2,3,999,0,1,2,3}, 3, -1, 1, 0, {});
    check({1,1,1,1}, 2, 1, 4, 0, {1});
    check({1,2,3}, 4, -1, 4, -1, {});
    check(repeated, 0, 4, 4, -1, {});
    std::cout << "lookup suffix cases passed\n";
}
