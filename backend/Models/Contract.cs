using System;
using System.ComponentModel.DataAnnotations;

namespace quanlyphongtro.Models
{
    public class Contract
    {
        [Key]
        public int Id { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập họ tên")]
        [Display(Name = "Họ và tên")]
        public string FullName { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập số CCCD")]
        [Display(Name = "Số CCCD")]
        public string CCCD { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập địa chỉ thường trú")]
        [Display(Name = "Địa chỉ thường trú")]
        public string Address { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập số điện thoại")]
        [Phone(ErrorMessage = "Số điện thoại không hợp lệ")]
        [Display(Name = "Số điện thoại")]
        public string PhoneNumber { get; set; }

        // --- CÁC TRƯỜNG MỚI THÊM ---

        [Required(ErrorMessage = "Vui lòng chọn ngày bắt đầu ở")]
        [Display(Name = "Ngày bắt đầu ở")]
        [DataType(DataType.Date)]
        public DateTime StartDate { get; set; } = DateTime.Now;

        [Required(ErrorMessage = "Vui lòng chọn thời hạn hợp đồng")]
        [Display(Name = "Thời hạn thuê (Năm)")]
        [Range(1, 10, ErrorMessage = "Thời hạn từ 1 đến 10 năm")]
        public int ContractTerm { get; set; } // Người dùng sẽ chọn 1, 2... năm

        [Display(Name = "Ngày kết thúc hợp đồng")]
        [DataType(DataType.Date)]
        public DateTime EndDate { get; set; }

        // ---------------------------

        public DateTime CreatedDate { get; set; } = DateTime.Now;

        public string Status { get; set; } = "Pending";
    }
}