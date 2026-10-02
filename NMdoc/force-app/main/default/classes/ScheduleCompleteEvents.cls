public class ScheduleCompleteEvents implements Schedulable {
    public void execute(SchedulableContext sc) {
        BatchCompleteEvents batch = new BatchCompleteEvents();
        Database.executeBatch(batch, 200);
    }
}