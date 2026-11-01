using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quanlyphongtro.DATA;
using quanlyphongtro.Models;
using quanlyphongtro.Models.Api;

namespace quanlyphongtro.Controllers.Api
{
    [ApiController]
    [Route("api/contracts")]
    public class ContractsApiController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public ContractsApiController(ApplicationDbContext context)
        {
            _context = context;
        }

        private string? Role => HttpContext.Session.GetString("Role")?.ToLower();
        private bool LoggedIn => HttpContext.Session.GetString("User") != null;

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            if (Role != "owner" && Role != "manager")
                return StatusCode(403, new { message = "Bạn không có quyền xem danh sách hợp đồng." });

            var contracts = await _context.Contracts.AsNoTracking()
                .OrderByDescending(c => c.CreatedDate)
                .ToListAsync();

            return Ok(contracts);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] ContractRequest request)
        {
            if (!LoggedIn) return Unauthorized(new { message = "Chưa đăng nhập." });
            if (string.IsNullOrWhiteSpace(request.FullName) ||
                string.IsNullOrWhiteSpace(request.CCCD) ||
                string.IsNullOrWhiteSpace(request.Address) ||
                string.IsNullOrWhiteSpace(request.PhoneNumber))
                return BadRequest(new { message = "Vui lòng nhập đầy đủ thông tin hợp đồng." });
            if (request.ContractTerm < 1 || request.ContractTerm > 10)
                return BadRequest(new { message = "Thời hạn hợp đồng phải từ 1 đến 10 năm." });

            var startDate = request.StartDate == default ? DateTime.Today : request.StartDate.Date;
            var contract = new Contract
            {
                FullName = request.FullName,
                CCCD = request.CCCD,
                Address = request.Address,
                PhoneNumber = request.PhoneNumber,
                StartDate = startDate,
                ContractTerm = request.ContractTerm,
                EndDate = startDate.AddYears(request.ContractTerm),
                CreatedDate = DateTime.Now,
                Status = "Pending"
            };

            _context.Contracts.Add(contract);
            await _context.SaveChangesAsync();
            return Ok(new { success = true, contract.Id });
        }

        [HttpPost("{id:int}/approve")]
        public async Task<IActionResult> Approve(int id)
        {
            if (Role != "owner" && Role != "manager")
                return StatusCode(403, new { message = "Bạn không có quyền duyệt hợp đồng." });

            var contract = await _context.Contracts.FindAsync(id);
            if (contract == null) return NotFound(new { message = "Không tìm thấy hợp đồng." });

            contract.Status = "Approved";
            await _context.SaveChangesAsync();
            return Ok(new { success = true });
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            if (Role != "owner" && Role != "manager")
                return StatusCode(403, new { message = "Bạn không có quyền xóa hợp đồng." });

            var contract = await _context.Contracts.FindAsync(id);
            if (contract == null) return NotFound(new { message = "Không tìm thấy hợp đồng." });

            _context.Contracts.Remove(contract);
            await _context.SaveChangesAsync();
            return Ok(new { success = true });
        }
    }
}
