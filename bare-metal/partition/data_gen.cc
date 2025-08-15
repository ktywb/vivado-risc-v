#include <fmt/core.h>

#include <fstream>
#include <iomanip>
#include <random>

#include "csrc/config.h"

const int SEED = Partition::SEED;
const int TUPLE_NUM = Partition::TUPLE_NUM;

int main(int argc, char *argv[]) {
  std::mt19937 gen(SEED);
  std::uniform_int_distribution<uint32_t> dis(0, UINT32_MAX);

  std::ofstream cache_line_file("data/cache_line.mem");
  std::ofstream tuple_length_file("data/tuple_length.mem");
  std::ofstream key_file("data/key.mem");

  int sum_tuple_length = 0;
  for (int i = 0; i < TUPLE_NUM; i++) {
    // 定长

    // 8 63
    // 9 44
    // 10 49.78
    // 11 54.782
    // 12 59.76
    // 13 51.86
    // 14 55.85
    // 15 59.82
    // 24 47.938
    // 27 53.92
    // 28 55.916
    // 29 57.94
    // 32 63.92
    // auto dis_tuple_length = 28;
    // auto dis_key_offset = 0;
    // auto dis_key_length = 4;

    // 8-16B tuple, 4-8B key
    // auto dis_tuple_length = dis(gen) % 8 + 8;
    // auto dis_key_offset = dis(gen) % 4;
    // auto remain = dis_tuple_length - dis_key_offset;
    // auto dis_key_length =
    //   remain == 4 ? 4 :
    //     4 + (dis(gen) % (remain - 4));

    // 24-32B tuple, 4-16B key
    auto dis_tuple_length = dis(gen) % 8 + 24;
    auto dis_key_offset = dis(gen) * 0;
    auto remain = dis_tuple_length - dis_key_offset;
    auto dis_key_length = 4 + (dis(gen) % (16 - 4));

    sum_tuple_length += dis_tuple_length;

    tuple_length_file << std::hex << std::setw(2) << std::setfill('0')
                      << dis_tuple_length;
    if (i % 8 == 7) {
      tuple_length_file << std::endl;
    }
    key_file << std::hex << std::setw(2) << std::setfill('0') << dis_key_offset
             << std::hex << std::setw(2) << std::setfill('0') << dis_key_length;
    if (i % 8 == 7) {
      key_file << std::endl;
    }
  }

  int cache_line_num = (sum_tuple_length + 63) / 64;
  for (int i = 0; i < cache_line_num; i++) {
    for (int j = 0; j < 16; j++) {
      cache_line_file << std::hex << std::setw(8) << std::setfill('0')
                      << dis(gen);
    }
    cache_line_file << std::endl;
  }
  fmt::print("cache line num: {}\n", cache_line_num);

  cache_line_file.close();
  tuple_length_file.close();
  key_file.close();
  return 0;
}
