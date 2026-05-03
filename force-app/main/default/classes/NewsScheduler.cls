global class NewsScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        NewsIngestionFlow.run();
    }
}