using Microsoft.EntityFrameworkCore;
using quanlyphongtro.Models;

namespace quanlyphongtro.DATA
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<User> Users { get; set; }
        public DbSet<Room> Rooms { get; set; }
        public DbSet<Invoice> Invoices { get; set; }
                
        public DbSet<Contract> Contracts { get; set; }
    }
}