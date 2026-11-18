#pragma once

#include <algorithm>
#include <cstddef>
#include <vector>

namespace fnx {
constexpr int LOOKUP_N = 3;

inline std::vector<int> select_lookup_drafts(const std::vector<int>& ctx, int limit, int first_draft,
                                             int sources, int image_token, int* match) {
    if (match) *match = -1;
    if (limit <= 0 || ctx.size() <= LOOKUP_N) return {};
    const std::size_t suffix = ctx.size() - LOOKUP_N;
    int best_length = 0;
    std::size_t best_start = 0;
    for (std::size_t pos = suffix; pos-- > 0;) {
        if (!std::equal(ctx.begin() + pos, ctx.begin() + pos + LOOKUP_N, ctx.begin() + suffix)) continue;
        if (first_draft < 0 || ctx[pos + LOOKUP_N] == first_draft) {
            int length = LOOKUP_N;
            while (length < limit && static_cast<std::size_t>(length - LOOKUP_N) < pos) {
                const std::size_t offset = length - LOOKUP_N + 1;
                if (ctx[pos - offset] != ctx[suffix - offset]) break;
                ++length;
            }
            if (length > best_length) {
                best_length = length;
                best_start = pos;
            }
        }
        // Visit newest first so equal-length suffixes retain the most recent continuation.
        if (--sources == 0 || best_length >= limit) break;
    }
    if (!best_length) return {};
    if (match) *match = static_cast<int>(best_start);
    const auto begin = ctx.begin() + best_start + LOOKUP_N;
    const auto end = begin + std::min<std::ptrdiff_t>(ctx.end() - begin, std::min(limit, best_length));
    const auto first_image = std::find_if(begin, end, [image_token](int token) { return token >= image_token; });
    return {begin, first_image};
}
}  // namespace fnx
