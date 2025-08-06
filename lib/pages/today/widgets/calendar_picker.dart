import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarPicker extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final VoidCallback onClose;

  const CalendarPicker({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onClose,
  });

  @override
  State<CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<CalendarPicker>
    with TickerProviderStateMixin {
  late DateTime _currentMonth;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeCalendar() async {
    await _animationController.reverse();
    widget.onClose();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;
    
    final days = <Widget>[];
    
    // 添加周标题
    const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    for (final weekDay in weekDays) {
      days.add(
        Container(
          height: 32,
          alignment: Alignment.center,
          child: Text(
            weekDay,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    
    // 添加前一个月的日期（填充）
    final previousMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    final lastDayOfPreviousMonth = DateTime(previousMonth.year, previousMonth.month + 1, 0);
    
    for (int i = firstDayOfWeek - 1; i >= 0; i--) {
      final date = DateTime(
        lastDayOfPreviousMonth.year,
        lastDayOfPreviousMonth.month,
        lastDayOfPreviousMonth.day - i,
      );
      days.add(_buildDateCell(date, isCurrentMonth: false));
    }
    
    // 添加当前月的日期
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      days.add(_buildDateCell(date, isCurrentMonth: true));
    }
    
    // 添加下个月的日期（填充到6行）
    final totalCells = 7 * 6; // 6 rows
    final remainingCells = totalCells - days.length + 7; // +7 for week headers
    
    for (int day = 1; day <= remainingCells; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month + 1, day);
      days.add(_buildDateCell(date, isCurrentMonth: false));
    }
    
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: days,
    );
  }

  Widget _buildDateCell(DateTime date, {required bool isCurrentMonth}) {
    final isSelected = _isSameDay(date, widget.selectedDate);
    final isToday = _isToday(date);
    
    return GestureDetector(
      onTap: () {
        widget.onDateSelected(date);
        _closeCalendar();
      },
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? (isToday ? Colors.blue : Colors.grey[300])
              : (isToday ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
            color: !isCurrentMonth
                ? Colors.grey[400]
                : isSelected
                    ? (isToday ? Colors.white : Colors.grey[700])
                    : (isToday ? Colors.blue[600] : Colors.black87),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeCalendar,
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Stack(
          children: [
            Positioned(
              top: 100,
              right: 16,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Material(
                        elevation: 12,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 320,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header with month navigation
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: _previousMonth,
                                    icon: const Icon(Icons.chevron_left),
                                    iconSize: 24,
                                    color: Colors.grey[600],
                                  ),
                                  Expanded(
                                    child: Text(
                                      DateFormat('MMMM yyyy').format(_currentMonth),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _nextMonth,
                                    icon: const Icon(Icons.chevron_right),
                                    iconSize: 24,
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Calendar grid
                              _buildCalendarGrid(),
                              const SizedBox(height: 12),
                              // Quick actions
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () {
                                        widget.onDateSelected(DateTime.now());
                                        _closeCalendar();
                                      },
                                      child: Text(
                                        'Today',
                                        style: TextStyle(
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _closeCalendar,
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 