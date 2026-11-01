namespace quanlyphongtro.Models.Api
{
    public class LoginRequest
    {
        public string Username { get; set; } = "";
        public string Password { get; set; } = "";
    }

    public class RoomRequest
    {
        public string? RoomName { get; set; }
        public decimal Price { get; set; }
        public bool Status { get; set; }
        public string? TenantUsername { get; set; }
        public decimal ElectricPrice { get; set; } = 3500;
        public decimal WaterPrice { get; set; } = 20000;
        public decimal WifiPrice { get; set; } = 50000;
        public bool HasWifi { get; set; }
        public decimal TrashPrice { get; set; } = 10000;
    }

    public class InvoiceRequest
    {
        public int RoomId { get; set; }
        public int Month { get; set; }
        public int Year { get; set; }
        public int ElectricOld { get; set; }
        public int ElectricNew { get; set; }
        public int WaterOld { get; set; }
        public int WaterNew { get; set; }
    }

    public class ContractRequest
    {
        public string FullName { get; set; } = "";
        public string CCCD { get; set; } = "";
        public string Address { get; set; } = "";
        public string PhoneNumber { get; set; } = "";
        public DateTime StartDate { get; set; }
        public int ContractTerm { get; set; }
    }

    public class UserRequest
    {
        public string Username { get; set; } = "";
        public string Password { get; set; } = "";
        public string? FullName { get; set; }
        public string Role { get; set; } = "Tenant";
        public int? RoomId { get; set; }
    }
}
