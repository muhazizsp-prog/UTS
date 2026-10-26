// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PharmaTrace
 * @notice Sistem Pelacakan Rantai Pasok Obat dan Vaksin Berbasis Blockchain:
 *         status batch, lokasi, tanggal kedaluwarsa, dan rantai kepemilikan
 *         dari produsen hingga apotek.
 */
contract PharmaTrace {


    enum StatusProduk { Diproduksi, DalamPengiriman, DiterimaApotek, Ditolak, Dikembalikan, Dibuang }

    uint8 private constant JUMLAH_STATUS = 6;
    uint private constant OFFSET_WIB = 7 hours;


    struct BatchObat {
        uint idBatch;
        string namaProduk;
        uint jumlahProduk;
        int suhuPenyimpanan;
        string lokasiSaatIni;
        StatusProduk status;
        address pemilik;
        uint tanggalKedaluwarsa; 
    }

    struct DetailBatch {
        uint idBatch;
        string namaProduk;
        uint jumlahProduk;
        int suhuPenyimpanan;
        string lokasiSaatIni;
        string status;
        string namaPemilik;
        uint tanggalKedaluwarsa;
        string kedaluwarsaWIB;
        bool sudahKedaluwarsa;
    }

    struct RiwayatPemilik {
        address pemilik;
        uint waktu;
    }

    struct RiwayatTampil {
        string namaPemilik;
        string waktu;
    }



    address public admin;
    uint public totalBatch;

    mapping(uint => BatchObat) private daftarBatch;
    mapping(uint => RiwayatPemilik[]) private rantaiKepemilikan; // riwayat pemilik per batch
    mapping(address => string) private namaAkun;

    // =========================================================
    // 3. EVENT
    // =========================================================

    event BatchDibuat(uint indexed idBatch, string namaProduk, address pemilik);
    event StatusDiperbarui(uint indexed idBatch, string statusBaru, string lokasiBaru);
    event KepemilikanDitransfer(uint indexed idBatch, address indexed dari, address indexed ke, string namaPemilikBaru);

    // =========================================================
    // 4. MODIFIER
    // =========================================================

    modifier onlyAdmin() {
        require(msg.sender == admin, "Akses ditolak: Hanya admin/produsen yang diizinkan!");
        _;
    }

    modifier batchValid(uint _idBatch) {
        require(_idBatch > 0 && _idBatch <= totalBatch, "Batch obat tidak ditemukan!");
        _;
    }

    modifier onlyPemilik(uint _idBatch) {
        require(msg.sender == daftarBatch[_idBatch].pemilik, "Anda bukan pemilik batch ini!");
        _;
    }

    // Batch yang sudah melewati tanggal kedaluwarsa tidak boleh diubah/ditransfer
    modifier belumKedaluwarsa(uint _idBatch) {
        require(block.timestamp <= daftarBatch[_idBatch].tanggalKedaluwarsa, "Batch sudah kedaluwarsa!");
        _;
    }


    constructor() {
        admin = msg.sender;
        namaAkun[msg.sender] = "admin";
    }


    function tambahBatchObat(
        string memory _namaProduk,
        uint _jumlahProduk,
        int _suhuPenyimpanan,
        string memory _lokasi,
        uint _tanggalKedaluwarsa
    ) public onlyAdmin {
        require(bytes(_namaProduk).length > 0, "Nama produk tidak boleh kosong!");
        require(_jumlahProduk > 0, "Jumlah barang harus lebih dari 0!");
        require(bytes(_lokasi).length > 0, "Lokasi tidak boleh kosong!");
        require(_tanggalKedaluwarsa > block.timestamp, "Tanggal kedaluwarsa harus setelah tanggal pembuatan batch!");

        totalBatch++;

        BatchObat storage b = daftarBatch[totalBatch];
        b.idBatch = totalBatch;
        b.namaProduk = _namaProduk;
        b.jumlahProduk = _jumlahProduk;
        b.suhuPenyimpanan = _suhuPenyimpanan;
        b.lokasiSaatIni = _lokasi;
        b.status = StatusProduk.Diproduksi;
        b.pemilik = msg.sender;
        b.tanggalKedaluwarsa = _tanggalKedaluwarsa;

        rantaiKepemilikan[totalBatch].push(RiwayatPemilik(msg.sender, block.timestamp));

        emit BatchDibuat(totalBatch, _namaProduk, msg.sender);
    }

    function updateLogistik(
        uint _idBatch,
        string memory _lokasiBaru,
        uint8 _kodeStatus
    ) public batchValid(_idBatch) onlyPemilik(_idBatch) belumKedaluwarsa(_idBatch) {
        require(bytes(_lokasiBaru).length > 0, "Lokasi tidak boleh kosong!");
        require(_kodeStatus < JUMLAH_STATUS, "Kode status tidak valid! Gunakan angka 0 sampai 5.");

        StatusProduk statusBaru = StatusProduk(_kodeStatus);

        daftarBatch[_idBatch].lokasiSaatIni = _lokasiBaru;
        daftarBatch[_idBatch].status = statusBaru;

        emit StatusDiperbarui(_idBatch, _statusKeString(statusBaru), _lokasiBaru);
    }

    function transferKepemilikan(
        uint _idBatch,
        address _pemilikBaru,
        string memory _namaPemilikBaru
    ) public batchValid(_idBatch) onlyPemilik(_idBatch) belumKedaluwarsa(_idBatch) {
        require(_pemilikBaru != address(0), "Alamat dompet penerima tidak valid!");
        require(_pemilikBaru != msg.sender, "Penerima tidak boleh sama dengan pemilik saat ini!");

        if (_pemilikBaru != admin) {
            require(bytes(_namaPemilikBaru).length > 0, "Nama penerima tidak boleh kosong!");
            namaAkun[_pemilikBaru] = _namaPemilikBaru;
        }

        daftarBatch[_idBatch].pemilik = _pemilikBaru;
        rantaiKepemilikan[_idBatch].push(RiwayatPemilik(_pemilikBaru, block.timestamp));

        emit KepemilikanDitransfer(_idBatch, msg.sender, _pemilikBaru, _namaDari(_pemilikBaru));
    }

    function lihatNamaStatus(uint8 _kodeStatus) public pure returns (string memory) {
        require(_kodeStatus < JUMLAH_STATUS, "Kode status tidak valid! Gunakan angka 0 sampai 5.");
        return _statusKeString(StatusProduk(_kodeStatus));
    }

    /// @notice Detail lengkap batch; status dan pemilik tampil sebagai teks.
    function getDetailBatch(uint _idBatch)
        public
        view
        batchValid(_idBatch)
        returns (DetailBatch memory)
    {
        BatchObat storage b = daftarBatch[_idBatch];
        DetailBatch memory d;
        d.idBatch = b.idBatch;
        d.namaProduk = b.namaProduk;
        d.jumlahProduk = b.jumlahProduk;
        d.suhuPenyimpanan = b.suhuPenyimpanan;
        d.lokasiSaatIni = b.lokasiSaatIni;
        d.status = _statusKeString(b.status);
        d.namaPemilik = _namaDari(b.pemilik);
        d.tanggalKedaluwarsa = b.tanggalKedaluwarsa;
        d.kedaluwarsaWIB = _formatWaktu(b.tanggalKedaluwarsa);
        d.sudahKedaluwarsa = block.timestamp > b.tanggalKedaluwarsa;
        return d;
    }

    function getRantaiKepemilikan(uint _idBatch)
        public
        view
        batchValid(_idBatch)
        returns (RiwayatTampil[] memory)
    {
        RiwayatPemilik[] storage asli = rantaiKepemilikan[_idBatch];
        RiwayatTampil[] memory hasil = new RiwayatTampil[](asli.length);

        for (uint i = 0; i < asli.length; i++) {
            hasil[i] = RiwayatTampil({
                namaPemilik: _namaDari(asli[i].pemilik),
                waktu: _formatWaktu(asli[i].waktu)
            });
        }
        return hasil;
    }


    function cekRantaiKepemilikan(uint _idBatch)
        public
        view
        batchValid(_idBatch)
        returns (bool rantaiUtuh, address[] memory urutanPemilik)
    {
        RiwayatPemilik[] storage asli = rantaiKepemilikan[_idBatch];
        uint n = asli.length;
        urutanPemilik = new address[](n);

        rantaiUtuh = n > 0
            && asli[0].pemilik == admin
            && asli[n - 1].pemilik == daftarBatch[_idBatch].pemilik;

        for (uint i = 0; i < n; i++) {
            urutanPemilik[i] = asli[i].pemilik;
            if (i > 0 && (asli[i].pemilik == asli[i - 1].pemilik || asli[i].waktu < asli[i - 1].waktu)) {
                rantaiUtuh = false;
            }
        }
    }

    function getJumlahPemilik(uint _idBatch) public view batchValid(_idBatch) returns (uint) {
        return rantaiKepemilikan[_idBatch].length;
    }

    function getNama(address _akun) public view returns (string memory) {
        return _namaDari(_akun);
    }

    /// @notice Timestamp Unix saat ini (bantuan untuk mengisi tanggal kedaluwarsa saat pengujian).
    function waktuSekarang() public view returns (uint) {
        return block.timestamp;
    }

    // =========================================================
    // 8. FUNGSI INTERNAL
    // =========================================================

    function _namaDari(address _akun) internal view returns (string memory) {
        string memory n = namaAkun[_akun];
        if (bytes(n).length == 0) return "Belum ada nama";
        return n;
    }

    // Konversi enum StatusProduk -> teks; seluruh 6 nilai enum ditangani eksplisit.
    function _statusKeString(StatusProduk _status) internal pure returns (string memory) {
        if (_status == StatusProduk.Diproduksi) return "Diproduksi";
        if (_status == StatusProduk.DalamPengiriman) return "DalamPengiriman";
        if (_status == StatusProduk.DiterimaApotek) return "DiterimaApotek";
        if (_status == StatusProduk.Ditolak) return "Ditolak";
        if (_status == StatusProduk.Dikembalikan) return "Dikembalikan";
        if (_status == StatusProduk.Dibuang) return "Dibuang";
        revert("Status tidak dikenal!");
    }

    // =========================================================
    // 9. FUNGSI FORMAT WAKTU (timestamp -> tanggal WIB)
    // =========================================================

    /// @dev Contoh hasil: "24 Oktober 2026 18:32:30 WIB"
    function _formatWaktu(uint _timestamp) internal pure returns (string memory) {
        uint t = _timestamp + OFFSET_WIB;
        return string(abi.encodePacked(
            _formatTanggal(t / 1 days),
            " ",
            _formatJam(t % 1 days),
            " WIB"
        ));
    }

    function _formatTanggal(uint _hari) internal pure returns (string memory) {
        (uint tahun, uint bulan, uint tanggal) = _hariKeTanggal(_hari);
        return string(abi.encodePacked(
            _uintKeString(tanggal), " ", _namaBulan(bulan), " ", _uintKeString(tahun)
        ));
    }

    function _formatJam(uint _detikDalamHari) internal pure returns (string memory) {
        uint jam = _detikDalamHari / 1 hours;
        uint menit = (_detikDalamHari % 1 hours) / 1 minutes;
        uint detik = _detikDalamHari % 1 minutes;
        return string(abi.encodePacked(_duaDigit(jam), ":", _duaDigit(menit), ":", _duaDigit(detik)));
    }

    /// @dev Mengubah jumlah hari sejak 1 Jan 1970 menjadi tahun-bulan-tanggal
    ///      (algoritma kalender Gregorian, mengacu pada pustaka BokkyPooBah DateTime).
    function _hariKeTanggal(uint _hari) internal pure returns (uint tahun, uint bulan, uint tanggal) {
        int __days = int(_hari);

        int L = __days + 68569 + 2440588;
        int N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int _year = 4000 * (L + 1) / 1461001;
        L = L - 1461 * _year / 4 + 31;
        int _month = 80 * L / 2447;
        int _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        tahun = uint(_year);
        bulan = uint(_month);
        tanggal = uint(_day);
    }

    function _namaBulan(uint _bulan) internal pure returns (string memory) {
        if (_bulan == 1) return "Januari";
        if (_bulan == 2) return "Februari";
        if (_bulan == 3) return "Maret";
        if (_bulan == 4) return "April";
        if (_bulan == 5) return "Mei";
        if (_bulan == 6) return "Juni";
        if (_bulan == 7) return "Juli";
        if (_bulan == 8) return "Agustus";
        if (_bulan == 9) return "September";
        if (_bulan == 10) return "Oktober";
        if (_bulan == 11) return "November";
        return "Desember";
    }

    function _duaDigit(uint _angka) internal pure returns (string memory) {
        if (_angka < 10) {
            return string(abi.encodePacked("0", _uintKeString(_angka)));
        }
        return _uintKeString(_angka);
    }

    function _uintKeString(uint _nilai) internal pure returns (string memory) {
        if (_nilai == 0) return "0";

        uint temp = _nilai;
        uint digit;
        while (temp != 0) {
            digit++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digit);
        while (_nilai != 0) {
            digit--;
            buffer[digit] = bytes1(uint8(48 + _nilai % 10));
            _nilai /= 10;
        }
        return string(buffer);
    }
}
