using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace quanlyphongtro.Migrations
{
    public partial class CreateContractTableFinal : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ĐÃ LƯỢC BỎ CÁC DÒNG ADD COLUMN CHO BẢNG ROOMS ĐỂ TRÁNH LỖI TRÙNG LẶP

            migrationBuilder.CreateTable(
                name: "Contracts",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    FullName = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CCCD = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Address = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    PhoneNumber = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    StartDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ContractTerm = table.Column<int>(type: "int", nullable: false),
                    EndDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Contracts", x => x.Id);
                });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Chỉ xóa bảng Contracts khi cần Rollback
            migrationBuilder.DropTable(
                name: "Contracts");
        }
    }
}