namespace Ec2Manager.Models;

public class User
{
    public int Id { get; set; }
    public string Username { get; set; } = "";
    public string Email { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class Schedule
{
    public int Id { get; set; }

    public string Name { get; set; } = "";
    public string AccountKey { get; set; } = "";

    // Stored as JSON strings in DB (Pomelo/MySQL doesn't natively support List<T> columns)
    public List<string> Regions { get; set; } = new();
    public List<string> InstanceIds { get; set; } = new(); // empty = all matching filters

    public string Action { get; set; } = "Start"; // "Start" or "Stop"

    // Time window
    public DateTimeOffset? ValidFrom { get; set; }
    public DateTimeOffset? ValidTo { get; set; }

    // Recurrence (windowed mode)
    public string? RecurrenceType { get; set; } // "None", "Daily", "Weekly"
    public List<string>? DaysOfWeek { get; set; } // e.g. ["Mon","Wed","Fri"]
    public TimeSpan? TimeOfDay { get; set; }

    // Cron mode (mutually exclusive with recurrence fields)
    public string? CronExpression { get; set; }

    public bool Enabled { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public string CreatedBy { get; set; } = "";

    // Bookkeeping for the background runner so we don't double-fire in the
    // same minute if the poll interval and schedule granularity overlap.
    public DateTime? LastFiredAt { get; set; }
}

public class AuditLog
{
    public int Id { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;

    public int? UserId { get; set; }
    public string UserName { get; set; } = "";

    public string ActionType { get; set; } = ""; // ManualStart, ManualStop, ScheduleStart, ScheduleStop
    public string AccountKey { get; set; } = "";
    public string Region { get; set; } = "";

    public List<string> InstanceIds { get; set; } = new();

    public bool DryRun { get; set; }
    public string Result { get; set; } = ""; // Success, Failed, Partial
    public string Message { get; set; } = "";
    public string? Error { get; set; }
}
