using System.ComponentModel.DataAnnotations.Schema;

namespace quanlyphongtro.Models
{
    public class Room
    {
        public int Id { get; set; }

        public string? RoomName { get; set; }

        public decimal Price { get; set; }

        // Status: true (còn trống), false (đã thuê)
        public bool Status { get; set; }

        public string? TenantUsername { get; set; }

        // Những thông số này giúp MANAGER nhập liệu và USER tự tính tiền

        public decimal ElectricPrice { get; set; } = 3500; // Giá điện

        public decimal WaterPrice { get; set; } = 20000;   // Giá nước

        public decimal WifiPrice { get; set; } = 50000;    // Phí Wifi

        public bool HasWifi { get; set; }

        public decimal TrashPrice { get; set; } = 10000;   // Phí rác
    }
}