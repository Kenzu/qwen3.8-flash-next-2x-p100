#include "lookup_suffix.hpp"

#include <iostream>
#include <stdexcept>

void check(const std::vector<int>& ctx, int limit, int first, int sources, int pos, const std::vector<int>& expected, int extend_min = 0) {
    int match = -2;
    auto result = fnx::select_lookup_drafts(ctx, limit, first, sources, 999, &match, extend_min);
    if (match != pos || result != expected) throw std::runtime_error("unexpected lookup drafts or match position");
}

void check_index8() {
    fnx::LookupIndex8 index;
    std::vector<int> ctx{1,2,3,4,5,6,7,8};
    const std::vector<int> prefix = ctx;
    int match = -2;
    auto lookup = [&](int first) { return fnx::select_lookup_drafts(ctx, 15, first, 4, 999, &match, 0, &index); };
    if (!lookup(-1).empty() || match != -1) throw std::runtime_error("matched an unfinished occurrence");
    ctx.insert(ctx.end(), {9,10,999});
    for (int i = 0; i < 4; ++i) ctx.insert(ctx.end(), {20+i,6,7,8,9,30+i});
    ctx.insert(ctx.end(), prefix.begin(), prefix.end());
    check(ctx, 15, 9, 4, 30, {9,33,1});
    if (lookup(9) != std::vector<int>{9,10} || match != 5) throw std::runtime_error("lost older match or image boundary");
    if (!lookup(12).empty() || match != -1) throw std::runtime_error("ignored first draft");
    const int recent = static_cast<int>(ctx.size()) - 3;
    ctx.insert(ctx.end(), {12,999});
    ctx.insert(ctx.end(), prefix.begin(), prefix.end());
    if (lookup(-1) != std::vector<int>{12} || match != recent) throw std::runtime_error("did not prefer recent equal match");
    if (lookup(9) != std::vector<int>{9,10} || match != 5) throw std::runtime_error("lost older eligible match");
    for (int i = 0; i < 4; ++i) {
        ctx.push_back(40+i);
        ctx.insert(ctx.end(), prefix.begin(), prefix.end());
    }
    if (!lookup(9).empty() || match != -1) throw std::runtime_error("exceeded four eight-token sources");
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
    const std::vector<int> copied{1,2,3,4,5,6,7,999,8,9,1,2,3,4};
    check(copied, 8, 5, 4, 1, {5,6,7}, 4);   // the image ends an extended proposal
    const std::vector<int> text{1,2,3,4,5,6,7,8,9,10,11,12,1,2,3,4};
    check(text, 7, 5, 4, 1, {5,6,7,8}, 5);  // below threshold
    check(text, 7, 5, 4, 1, {5,6,7,8,9,10,11}, 4);
    check(text, 3, 5, 4, 1, {5,6,7}, 3);    // never exceed configured lookup length
    check_index8();
    std::cout << "lookup suffix cases passed\n";
}
