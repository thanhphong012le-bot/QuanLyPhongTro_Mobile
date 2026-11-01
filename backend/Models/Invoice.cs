using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace quanlyphongtro.Models
{
    public class Invoice
    {
        public int Id { get; set; }

        public int RoomId { get; set; }
        [ForeignKey("RoomId")]
        public virtual Room? Room { get; set; }

        public int Month { get; set; }
        public int Year { get; set; }

        public int ElectricOld { get; set; }
        public int ElectricNew { get; set; }

        public int WaterOld { get; set; }
        public int WaterNew { get; set; }

        public bool IsPaid { get; set; } = false;

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalAmount { get; set; }

        public DateTime CreatedDate { get; set; } = DateTime.Now;
    }
}