using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace quanlyphongtro.Models
{
    public class User
    {
        public int Id { get; set; }

        [Required]
        public string Username { get; set; } = "";

        [Required]
        public string Password { get; set; } = "";

        public string? FullName { get; set; }

        // Quyền: "Owner", "Manager", "Tenant"
        public string Role { get; set; } = "Tenant";

        // Nếu Role là "Tenant", sẽ cho biết họ ở phòng nào
        public int? RoomId { get; set; }

        [ForeignKey("RoomId")]
        public virtual Room? Room { get; set; }
    }
}