// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PharmaSupplyChain {
    enum StatusProduk { Diproduksi, DalamPengiriman, DiterimaApotek, Ditolak }

    struct BatchObat {
        uint idBatch;
        string namaProduk;
        uint jumlahDosis;
        int suhuPenyimpanan;
        string lokasiSaatIni;
        StatusProduk status;
        address pemilik;
    }

    mapping(uint => BatchObat) public daftarBatch;

    address public admin;
    uint public totalBatch = 0;

    event BatchDibuat(uint indexed idBatch, string namaProduk, address pemilik);
    event StatusDiperbarui(uint indexed idBatch, StatusProduk statusBaru, string lokasiBaru);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Akses ditolak: Hanya admin/produsen yang diizinkan!");
        _;
    }

    constructor() {
        admin = msg.sender; 
    }

    function tambahBatchObat(
        string memory _namaProduk, 
        uint _jumlahDosis, 
        int _suhuPenyimpanan, 
        string memory _lokasi
    ) public onlyAdmin {
        totalBatch++;
        
        daftarBatch[totalBatch] = BatchObat({
            idBatch: totalBatch,
            namaProduk: _namaProduk,
            jumlahDosis: _jumlahDosis,
            suhuPenyimpanan: _suhuPenyimpanan,
            lokasiSaatIni: _lokasi,
            status: StatusProduk.Diproduksi,
            pemilik: msg.sender
        });

        emit BatchDibuat(totalBatch, _namaProduk, msg.sender);
    }

    function updateLogistik(
        uint _idBatch, 
        string memory _lokasiBaru, 
        StatusProduk _statusBaru
    ) public {

        require(_idBatch > 0 && _idBatch <= totalBatch, "Batch obat tidak ditemukan!");

        require(msg.sender == daftarBatch[_idBatch].pemilik, "Anda bukan pemilik batch ini!");

        daftarBatch[_idBatch].lokasiSaatIni = _lokasiBaru;
        daftarBatch[_idBatch].status = _statusBaru;

        emit StatusDiperbarui(_idBatch, _statusBaru, _lokasiBaru);
    }

    function transferKepemilikan(uint _idBatch, address _pemilikBaru) public {
        require(_idBatch > 0 && _idBatch <= totalBatch, "Batch tidak valid!");
        require(msg.sender == daftarBatch[_idBatch].pemilik, "Hanya pemilik saat ini yang dapat mentransfer!");
        require(_pemilikBaru != address(0), "Alamat dompet penerima tidak valid!");

        daftarBatch[_idBatch].pemilik = _pemilikBaru;
    }
}