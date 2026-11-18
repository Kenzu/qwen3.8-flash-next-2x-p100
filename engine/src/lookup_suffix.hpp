#pragma once

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <unordered_map>
#include <vector>

namespace fnx {
constexpr int LOOKUP_N = 3;

// Request-local. History grows only by appending tokens accepted by the verifier.
class LookupIndex8 {
    using Key = std::array<int, 8>;
    using Ends = std::array<int, 4>;
    struct Hash {
        std::size_t operator()(const Key& key) const {
            std::uint64_t hash = 14695981039346656037ull;
            for (int token : key) hash = (hash ^ static_cast<std::uint32_t>(token)) * 1099511628211ull;
            return static_cast<std::size_t>(hash);
        }
    };
    std::unordered_map<Key, Ends, Hash> recent_;
    std::size_t next_end_ = 8;

    static Key key_at(const std::vector<int>& ctx, std::size_t end) {
        Key key;
        std::copy_n(ctx.begin() + (end - key.size()), key.size(), key.begin());
        return key;
    }

public:
    std::array<int, 4> prior_ends(const std::vector<int>& ctx) {
        if (ctx.size() <= 8) return {};
        // Index only occurrences for which a continuation token is already known.
        for (; next_end_ < ctx.size(); ++next_end_) {
            auto& ends = recent_[key_at(ctx, next_end_)];
            std::move_backward(ends.begin(), ends.end() - 1, ends.end());
            ends[0] = static_cast<int>(next_end_);
        }
        auto it = recent_.find(key_at(ctx, ctx.size()));
        return it == recent_.end() ? Ends{} : it->second;
    }
};

inline std::vector<int> select_lookup_drafts(const std::vector<int>& ctx, int limit, int first_draft,
                                             int sources, int image_token, int* match, int extend_min = 0,
                                             LookupIndex8* index8 = nullptr) {
    if (match) *match = -1;
    if (limit <= 0 || ctx.size() <= LOOKUP_N) return {};
    const std::size_t suffix = ctx.size() - LOOKUP_N;
    int best_length = 0;
    std::size_t best_start = 0;
    auto consider = [&](std::size_t pos) {
        if (first_draft >= 0 && ctx[pos + LOOKUP_N] != first_draft) return;
        int length = LOOKUP_N;
        while (length < limit && static_cast<std::size_t>(length - LOOKUP_N) < pos) {
            const std::size_t offset = length - LOOKUP_N + 1;
            if (ctx[pos - offset] != ctx[suffix - offset]) break;
            ++length;
        }
        if (length > best_length || (length == best_length && pos > best_start)) {
            best_length = length;
            best_start = pos;
        }
    };
    for (std::size_t pos = suffix; pos-- > 0;) {
        if (!std::equal(ctx.begin() + pos, ctx.begin() + pos + LOOKUP_N, ctx.begin() + suffix)) continue;
        consider(pos);
        if (--sources == 0 || best_length >= limit) break;
    }
    if (index8 && best_length < limit) {
        for (int end : index8->prior_ends(ctx)) {
            if (end == 0) break;
            consider(end - LOOKUP_N);
        }
    }
    if (!best_length) return {};
    if (match) *match = static_cast<int>(best_start);
    const auto begin = ctx.begin() + best_start + LOOKUP_N;
    const bool extend = extend_min > 0 && best_length >= extend_min;
    const int proposal_length = extend ? limit : std::min(limit, best_length);
    const auto end = begin + std::min<std::ptrdiff_t>(ctx.end() - begin, proposal_length);
    const auto first_image = std::find_if(begin, end, [image_token](int token) { return token >= image_token; });
    return {begin, first_image};
}
}  // namespace fnx
