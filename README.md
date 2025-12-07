# IPv4 Packet Processor dengan Exact-Match Firewall

![image (1)](https://hackmd.io/_uploads/rJQXclXfWl.png)

Proyek VHDL lengkap dan dapat disintesis yang mengimplementasikan blok pemrosesan header IPv4 dengan firewall exact-match. Proyek ini mencakup praktikum Modul 2–9 dan ditargetkan untuk toolchain FPGA (Quartus/ModelSim).

## Daftar Isi

1. [Deskripsi Proyek](#deskripsi-proyek)
2. [Daftar File dan Fungsinya](#daftar-file-dan-fungsinya)
3. [Pemetaan Modul (Modul 2-9)](#pemetaan-modul-modul-2-9)
4. [Arsitektur Sistem](#arsitektur-sistem)
5. [Dokumentasi FSM dan Microcode](#dokumentasi-fsm-dan-microcode)
6. [Instruksi Kompilasi](#instruksi-kompilasi)
7. [Instruksi Simulasi](#instruksi-simulasi)
8. [Kasus Uji](#kasus-uji)
9. [Mengubah Daftar IP yang Diblokir](#mengubah-daftar-ip-yang-diblokir)
10. [Standar VHDL](#standar-vhdl)

---

## Deskripsi Proyek

Sistem ini menerima header IPv4 160-bit dan melakukan operasi berikut:

1. **Pemrosesan TTL**: Mengurangi field Time-To-Live; membuang paket jika TTL menjadi 0
2. **Perhitungan Ulang Checksum**: Menghitung ulang checksum header IPv4 setelah modifikasi TTL
3. **Pemeriksaan Firewall**: Melakukan perbandingan exact-match dari IP sumber dan tujuan terhadap daftar 10 IP yang diblokir berbasis ROM
4. **Keputusan Drop**: Menggabungkan alasan drop: `drop = drop_ttl OR drop_fw OR drop_checksum_error`

### Fitur Utama

- **Firewall exact-match saja** (tanpa CIDR/subnet matching)
- **Daftar IP yang diblokir berbasis ROM** (konstanta compile-time, tanpa RAM)
- **Kontrol microprogrammed** untuk urutan pemrosesan
- **Dapat disintesis** untuk target FPGA
- **Testbench komprehensif** dengan verifikasi berbasis assertion

---

## Daftar File dan Fungsinya

| File | Deskripsi | Modul Utama |
|------|-----------|-------------|
| `helpers.vhd` | Package fungsi dan prosedur | Modul 7 |
| `ttl_unit.vhd` | Pengurangan TTL dan deteksi drop | Modul 3 |
| `checksum_unit.vhd` | Perhitungan checksum IPv4 (dataflow) | Modul 2 |
| `firewall_rom_checker.vhd` | Firewall exact-match dengan ROM | Modul 6, 8 |
| `microcode_rom.vhd` | Penyimpanan ROM microcode | Modul 9 |
| `micro_controller.vhd` | Interpreter microinstruction | Modul 9 |
| `packet_processor.vhd` | Entity top-level struktural | Modul 5 |
| `firewall_checker_tb.vhd` | Testbench modul firewall | Modul 4 |
| `packet_processor_tb.vhd` | Testbench sistem top-level | Modul 4 |
| `README.md` | File dokumentasi ini | - |

---

## Pemetaan Modul (Modul 2-9)

### Modul 2: Deskripsi Dataflow

**File:** `checksum_unit.vhd`

**Baris yang mendemonstrasikan concurrent assignments (gaya dataflow):**

```vhdl
-- Lines 101-117: Word extraction (concurrent assignments)
word0 <= unsigned(header_zeroed(159 downto 144));
word1 <= unsigned(header_zeroed(143 downto 128));
-- ... etc.

-- Lines 120-132: Adder tree (concurrent dataflow)
sum_01 <= ('0' & word0) + ('0' & word1);
sum_23 <= ('0' & word2) + ('0' & word3);
sum_46 <= ('0' & word4) + ('0' & word6);
sum_78 <= ('0' & word7) + ('0' & word8);

-- Lines 135-141: Multi-level combination
sum_0123 <= ('0' & sum_01) + ('0' & sum_23);
sum_4678 <= ('0' & sum_46) + ('0' & sum_78);
sum_01234678 <= ('0' & sum_0123) + ('0' & sum_4678);
sum_all <= ('0' & sum_01234678) + ("0000" & sum_9);

-- Line 144: Final checksum (ones-complement)
checksum_new <= not std_logic_vector(...);
```

### Modul 3: Deskripsi Behavioral

**File:** `ttl_unit.vhd`

**Baris yang mendemonstrasikan proses behavioral:**

```vhdl
-- Lines 63-99: ttl_process
ttl_process : process(clk, rst)
    variable ttl_temp : unsigned(7 downto 0);
begin
    if rst = '1' then
        -- Asynchronous reset
        header_reg <= (others => '0');
        drop_reg   <= '0';
        valid_reg  <= '0';
    elsif rising_edge(clk) then
        if enable = '1' then
            -- Extract TTL, decrement, set drop flag
            ttl_temp := unsigned(header_in(95 downto 88));
            if ttl_temp <= 1 then
                drop_reg <= '1';
                ttl_out <= (others => '0');
            else
                drop_reg <= '0';
                ttl_out <= ttl_temp - 1;
            end if;
            -- ...
        end if;
    end if;
end process ttl_process;
```

### Modul 4: Testbench

**File:** `packet_processor_tb.vhd`, `firewall_checker_tb.vhd`

**Elemen-elemen testbench utama:**

- Proses pembangkit clock
- Instansiasi DUT melalui component
- Prosedur stimulus dengan wait statements
- Statement `assert` untuk verifikasi
- Statement `report` untuk output pengujian

```vhdl
-- Example from packet_processor_tb.vhd, lines 170-180
assert busy = '0' 
    report "FAIL: busy should be '0' after reset" severity error;
assert valid = '0' 
    report "FAIL: valid should be '0' after reset" severity error;
```

### Modul 5: Deskripsi Struktural

**File:** `packet_processor.vhd`

**Deklarasi component:** Baris 70-130
**Instansiasi component:** Baris 175-245

```vhdl
-- Lines 180-195: Microcontroller instantiation
u_micro_ctrl : micro_controller
    generic map (
        ADDR_WIDTH => 4,
        DATA_WIDTH => 16
    )
    port map (
        clk          => clk,
        rst          => rst,
        start        => start,
        -- ...
    );

-- Lines 200-210: TTL Unit instantiation
u_ttl : ttl_unit
    port map (
        clk            => clk,
        rst            => rst,
        enable         => ctrl_ttl_en,
        -- ...
    );
```

### Modul 6: Loop dan Generate Statements

**File:** `firewall_rom_checker.vhd`

**Statement FOR-GENERATE:** Baris 88-92

```vhdl
-- Concurrent comparator array using FOR-GENERATE
gen_comparators: for i in 0 to N_RULES-1 generate
    concurrent_matches(i) <= '1' when ip_reg = BLOCKED_IPS(i) else '0';
end generate gen_comparators;
```

**FOR loop dalam proses:** Baris 94-103

```vhdl
process(concurrent_matches)
    variable temp : std_logic;
begin
    temp := '0';
    for i in 0 to N_RULES-1 loop
        temp := temp or concurrent_matches(i);
    end loop;
    any_match_concurrent <= temp;
end process;
```

### Modul 7: Fungsi dan Prosedur

**File:** `helpers.vhd`

**Fungsi:**

| Fungsi | Baris | Deskripsi |
|--------|-------|----------|
| `ones_complement_add` | 97-103 | Penjumlahan ones-complement 16-bit |
| `ones_complement_add_fold` | 109-121 | Penjumlahan dengan carry folding |
| `prefix_to_mask` | 127-140 | Konversi prefix CIDR ke subnet mask |
| `ip_to_string` | 146-158 | Konversi alamat IP ke string |
| `compute_ipv4_checksum` | 174-202 | Perhitungan checksum lengkap |
| `extract_ttl` | 226-230 | Ekstraksi TTL dari header |
| `extract_src_ip` | 236-240 | Ekstraksi IP sumber |
| `extract_dst_ip` | 246-250 | Ekstraksi IP tujuan |

**Prosedur:**

| Prosedur | Baris | Deskripsi |
|----------|-------|----------|
| `report_test_result` | 208-220 | Melaporkan hasil test pass/fail |
| `wait_cycles` | 222-230 | Menunggu N siklus clock |

### Modul 8: Finite State Machines

**File:** `firewall_rom_checker.vhd`

**Definisi tipe state:** Baris 72-78

```vhdl
type state_t is (
    IDLE,           -- Menunggu sinyal start
    CHECKING,       -- Memeriksa aturan secara berurutan
    DONE_STATE      -- Pemeriksaan selesai
);
```

**Logika next state:** Baris 114-137
**Logika output:** Baris 143-185

### Modul 9: Microprogramming

**File:** `microcode_rom.vhd`, `micro_controller.vhd`

**Microcode ROM:** `microcode_rom.vhd`
- Format microinstruction (16 bit): Baris 30-40
- Isi ROM: Baris 90-125

**Microcontroller:** `micro_controller.vhd`
- Decode microinstruction: Baris 98-105
- Manajemen MPC: Baris 107-125
- Pembangkitan sinyal kontrol: Baris 127-185

---

## Arsitektur Sistem

```
                    +------------------+
                    |  packet_processor |  (Top-Level - Structural)
                    +------------------+
                            |
        +-------------------+-------------------+
        |                   |                   |
+---------------+  +----------------+  +-------------------+
| micro_controller |  |   ttl_unit   |  |  checksum_unit    |
+---------------+  +----------------+  +-------------------+
        |
+---------------+
| microcode_rom |
+---------------+
        
+---------------------+
| firewall_rom_checker |
+---------------------+
```

### Alur Data

```
header_in (160-bit)
       |
       v
  [TTL Unit] ---> TTL decremented, drop_ttl flag
       |
       v
  [Checksum Unit] ---> Checksum recomputed
       |
       v
  [Firewall (src)] ---> Check source IP
       |
       v
  [Firewall (dst)] ---> Check dest IP
       |
       v
  [Output Logic] ---> header_out, drop, valid
```

---

## Dokumentasi FSM dan Microcode

### Diagram State FSM Firewall

```
       +------+
       | IDLE |<--------+
       +------+         |
          |             |
    start='1'           |
          |             |
          v             |
     +----------+       |
     | CHECKING |       |
     +----------+       |
          |             |
    match OR            |
    all_checked         |
          |             |
          v             |
    +------------+      |
    | DONE_STATE |------+
    +------------+
```

### Format Microinstruction (16 bit)

| Bit | Field | Deskripsi |
|-----|-------|----------|
| 15 | TTL_EN | Aktifkan unit TTL |
| 14 | CKSUM_EN | Aktifkan unit Checksum |
| 13 | FW_START | Mulai pemeriksaan firewall |
| 12 | FW_SRC | 1=IP sumber, 0=IP tujuan |
| 11 | WAIT_FW | Tunggu penyelesaian firewall |
| 10 | SET_VALID | Set flag output valid |
| 9 | SET_DONE | Set flag selesai |
| 8:5 | RESERVED | Dicadangkan untuk penggunaan masa depan |
| 4:0 | NEXT_ADDR | Alamat microinstruction berikutnya |

### Urutan Microprogram

| Alamat | Label | Control Bits | Next | Deskripsi |
|--------|-------|--------------|------|-----------|
| 0 | IDLE | - | 1 | Tunggu start |
| 1 | TTL_PROC | TTL_EN=1 | 2 | Proses TTL |
| 2 | CKSUM_PROC | CKSUM_EN=1 | 3 | Hitung checksum |
| 3 | FW_SRC_ST | FW_START=1, FW_SRC=1 | 4 | Mulai firewall (sumber) |
| 4 | FW_SRC_WT | WAIT_FW=1 | 5 | Tunggu firewall |
| 5 | FW_DST_ST | FW_START=1, FW_SRC=0 | 6 | Mulai firewall (tujuan) |
| 6 | FW_DST_WT | WAIT_FW=1 | 7 | Tunggu firewall |
| 7 | OUTPUT | SET_VALID=1, SET_DONE=1 | 0 | Output hasil |

---

## Instruksi Kompilasi

### Intel Quartus Prime

1. Buat proyek baru: `File → New Project Wizard`
2. Tambahkan semua file VHDL ke proyek
3. Set `packet_processor` sebagai top-level entity
4. Pilih device FPGA target
5. Kompilasi: `Processing → Start Compilation`

```
quartus_sh --flow compile packet_processor
```

### Urutan Kompilasi File

1. `helpers.vhd`
2. `microcode_rom.vhd`
3. `ttl_unit.vhd`
4. `checksum_unit.vhd`
5. `firewall_rom_checker.vhd`
6. `micro_controller.vhd`
7. `packet_processor.vhd`

---

## Instruksi Simulasi

### ModelSim

```bash
# Create work library
vlib work

# Compile files in order
vcom -2008 helpers.vhd
vcom -2008 microcode_rom.vhd
vcom -2008 ttl_unit.vhd
vcom -2008 checksum_unit.vhd
vcom -2008 firewall_rom_checker.vhd
vcom -2008 micro_controller.vhd
vcom -2008 packet_processor.vhd
vcom -2008 firewall_checker_tb.vhd
vcom -2008 packet_processor_tb.vhd

# Run firewall testbench
vsim -c firewall_checker_tb -do "run -all; quit"

# Run top-level testbench
vsim -c packet_processor_tb -do "run -all; quit"

# Interactive simulation with waveform
vsim packet_processor_tb
add wave -radix hex /*
run -all
```

### Output Simulasi yang Diharapkan

```
# === Test 1: Reset Behavior ===
# PASS: Reset state verified
# === Test 2: TTL = 1 (Expires) ===
# PASS: drop='1' (expected)
# PASS: TTL=0 (expected)
# PASS: drop_ttl flag set correctly
# === Test 3: TTL = 64 (Normal) ===
# PASS: drop='0' (expected)
# PASS: TTL=63 (expected)
# PASS: Output checksum valid
# ... (more tests)
# ========================================
#            TEST SUMMARY
# ========================================
#   PASSED: XX
#   FAILED: 0
# ========================================
# ALL TESTS PASSED!
```

---

## Kasus Uji

### Kasus Uji packet_processor_tb.vhd

| Test # | Deskripsi | Input | Output yang Diharapkan |
|--------|-----------|-------|------------------------|
| 1 | Perilaku reset | rst='1' | busy='0', valid='0', drop='0' |
| 2 | TTL = 1 (kedaluwarsa) | TTL=1, IP tidak diblokir | drop='1', TTL_out=0 |
| 3 | TTL = 64 (normal) | TTL=64, IP tidak diblokir | drop='0', TTL_out=63, checksum valid |
| 4 | IP sumber yang diblokir | Semua 10 IP yang diblokir sebagai src | drop='1' (semua 10) |
| 5 | IP tujuan yang diblokir | Semua 10 IP yang diblokir sebagai dst | drop='1' (semua 10) |
| 6 | IP tidak diblokir | 10.1.0.7 | drop='0' |
| 7 | TTL = 0 | TTL=0 | drop='1', TTL_out=0 |
| 8 | Reset saat pemrosesan | rst='1' di tengah operasi | busy='0', valid='0' |
| 9 | Checksum valid | Header valid | dbg_drop_cksum='0' |
| 10 | Checksum corrupt | Header rusak | dbg_drop_cksum='1' |

### Daftar IP yang Diblokir

| Index | Alamat IP | Nilai Hex |
|-------|------------|-----------|
| 0 | 10.1.0.5 | 0x0A010005 |
| 1 | 10.1.0.10 | 0x0A01000A |
| 2 | 10.1.0.20 | 0x0A010014 |
| 3 | 192.168.1.100 | 0xC0A80164 |
| 4 | 192.168.1.101 | 0xC0A80165 |
| 5 | 172.16.0.5 | 0xAC100005 |
| 6 | 172.16.1.1 | 0xAC100101 |
| 7 | 203.0.113.5 | 0xCB007105 |
| 8 | 198.51.100.10 | 0xC633640A |
| 9 | 8.8.8.8 | 0x08080808 |

---

## Mengubah Daftar IP yang Diblokir

Untuk mengubah daftar IP yang diblokir:

1. Buka `firewall_rom_checker.vhd`

2. Temukan konstanta `BLOCKED_IPS` (sekitar baris 60):

```vhdl
constant BLOCKED_IPS : ip_rom_t := (
    0 => x"0A010005",   -- 10.1.0.5
    1 => x"0A01000A",   -- 10.1.0.10
    -- ... etc.
);
```

3. Ubah nilai hex sesuai kebutuhan. Format: `x"AABBCCDD"` di mana:
   - AA = oktet pertama
   - BB = oktet kedua
   - CC = oktet ketiga
   - DD = oktet keempat

4. Jika mengubah jumlah aturan, perbarui generic `N_RULES`:
   - Di nilai default generic `firewall_rom_checker.vhd`
   - Di generic map `packet_processor.vhd`

5. Kompilasi ulang dan sintesis ulang

### Contoh: Menambahkan IP baru

Untuk memblokir 1.2.3.4:
```vhdl
-- Konversi: 1.2.3.4 -> 01.02.03.04 -> x"01020304"
10 => x"01020304"   -- 1.2.3.4 (entri baru)
```

---

## Standar VHDL

Proyek ini menggunakan fitur **VHDL-2008** tetapi sebagian besar kompatibel dengan **VHDL-93**.

Fitur VHDL-2008 yang digunakan:
- Enhanced conditional expressions
- Mode `inOut` untuk parameter prosedur (di `helpers.vhd`)
- Block comments (opsional)

Untuk kepatuhan VHDL-93 yang ketat, modifikasi kecil mungkin diperlukan:
- Ganti `inOut` dengan parameter `in` dan `out` terpisah di prosedur
- Gunakan sensitivity list tradisional di proses

---

## Ringkasan Port Entity

### packet_processor (Top-Level)

| Port | Arah | Lebar | Deskripsi |
|------|------|-------|----------|
| clk | in | 1 | Clock sistem |
| rst | in | 1 | Reset asinkron (active high) |
| start | in | 1 | Pulsa mulai pemrosesan |
| header_in | in | 160 | Header IPv4 input |
| busy | out | 1 | Pemrosesan sedang berlangsung |
| valid | out | 1 | Output valid |
| drop | out | 1 | Paket harus dibuang |
| header_out | out | 160 | Header IPv4 yang telah diproses |
| dbg_drop_ttl | out | 1 | Debug: Flag drop TTL |
| dbg_drop_fw | out | 1 | Debug: Flag drop Firewall |
| dbg_drop_cksum | out | 1 | Debug: Flag error Checksum |

### Generics

| Generic | Default | Deskripsi |
|---------|---------|----------|
| N_RULES | 10 | Jumlah aturan IP yang diblokir |
| VERIFY_CHECKSUM | true | Aktifkan verifikasi checksum input |

---

## Lisensi

Proyek ini disediakan untuk tujuan pendidikan sebagai bagian dari praktikum Digilab DTE FTUI.

---

## Penulis

Lihat daftar [kontributor](https://github.com/davidalexander24/FINPRO-PSD-KEL7/graphs/contributors) yang berpartisipasi dalam proyek ini.

Kelompok 7:

- Tubagus Dafa Izza Fariz
- Kamila Salma Fathiyya
- Nicholas Edmund 
- David Alexander

Desember 2025

---