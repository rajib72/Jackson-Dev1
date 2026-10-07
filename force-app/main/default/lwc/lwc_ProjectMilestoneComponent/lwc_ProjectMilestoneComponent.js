import { LightningElement } from 'lwc';

export default class ProjectMilestoneProgressTracker extends LightningElement {
    selectedProject = 'digitalTransformation';
    selectedMilestone = 'stage1';
    selectedStage = 'all';
    selectedDateRange = 'mayJun';

    projectOptions = [
        { label: 'Digital Transformation', value: 'digitalTransformation' },
        { label: 'Salesforce Implementation', value: 'salesforceImplementation' },
        { label: 'Service Automation', value: 'serviceAutomation' }
    ];

    milestoneOptions = [
        { label: 'Stage 1', value: 'stage1' },
        { label: 'Stage 2', value: 'stage2' },
        { label: 'Stage 3', value: 'stage3' }
    ];

    stageOptions = [
        { label: 'All', value: 'all' },
        { label: 'Process 1', value: 'process1' },
        { label: 'Process 2', value: 'process2' },
        { label: 'Process 3', value: 'process3' },
        { label: 'Process 4', value: 'process4' }
    ];

    dateRangeOptions = [
        { label: '01 May 2026 - 30 Jun 2026', value: 'mayJun' },
        { label: '01 Jul 2026 - 31 Aug 2026', value: 'julAug' },
        { label: '01 Sep 2026 - 31 Oct 2026', value: 'sepOct' }
    ];

    demoData = {
        digitalTransformation: {
            stage1: {
                milestoneLabel: 'Stage 1',
                progress: 68,
                currentProcess: 'Process 2',
                startDate: '01 May 2026',
                endDate: '30 Jun 2026',
                firstMonth: 'May 2026',
                secondMonth: 'Jun 2026',
                dateRange: 'mayJun',
                dateMarkers: ['27 Apr', '04 May', '11 May', '18 May', '25 May', '01 Jun', '08 Jun', '15 Jun', '22 Jun', '29 Jun'],
                processes: [
                    {
                        key: 'process1',
                        name: 'Process 1',
                        date: '01 May – 10 May',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar green-bar',
                        style: 'left: 5%; width: 24%;',
                        markerClass: 'bar-marker green-marker',
                        icon: '✓'
                    },
                    {
                        key: 'process2',
                        name: 'Process 2',
                        date: '11 May – 25 May',
                        rowClass: 'chart-row active-row',
                        barClass: 'timeline-bar blue-bar',
                        style: 'left: 21%; width: 29%;',
                        markerClass: 'bar-marker blue-marker',
                        icon: ''
                    },
                    {
                        key: 'process3',
                        name: 'Process 3',
                        date: '26 May – 10 Jun',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar orange-bar',
                        style: 'left: 47%; width: 27%;',
                        markerClass: 'bar-marker orange-marker',
                        icon: ''
                    },
                    {
                        key: 'process4',
                        name: 'Process 4',
                        date: '11 Jun – 30 Jun',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar red-bar',
                        style: 'left: 62%; width: 38%;',
                        markerClass: 'bar-marker red-marker',
                        icon: '⚑'
                    }
                ],
                tasks: [
                    {
                        id: 'dt-s1-t1',
                        processKey: 'process1',
                        process: 'Process 1',
                        name: 'Requirement Review',
                        dueDate: '03 May 2026',
                        status: 'Completed',
                        statusIcon: '✓',
                        statusClass: 'status completed-status',
                        leftColor: 'row-line green-line',
                        isUpcoming: false
                    },
                    {
                        id: 'dt-s1-t2',
                        processKey: 'process1',
                        process: 'Process 1',
                        name: 'Design Approval',
                        dueDate: '08 May 2026',
                        status: 'Completed',
                        statusIcon: '✓',
                        statusClass: 'status completed-status',
                        leftColor: 'row-line green-line',
                        isUpcoming: false
                    },
                    {
                        id: 'dt-s1-t3',
                        processKey: 'process2',
                        process: 'Process 2',
                        name: 'Development Setup',
                        dueDate: '14 May 2026',
                        status: 'In Progress',
                        statusIcon: '◌',
                        statusClass: 'status progress-status',
                        leftColor: 'row-line blue-line',
                        isUpcoming: true
                    },
                    {
                        id: 'dt-s1-t4',
                        processKey: 'process2',
                        process: 'Process 2',
                        name: 'User Validation',
                        dueDate: '20 May 2026',
                        status: 'Pending',
                        statusIcon: '◷',
                        statusClass: 'status pending-status',
                        leftColor: 'row-line blue-line',
                        isUpcoming: true
                    },
                    {
                        id: 'dt-s1-t5',
                        processKey: 'process3',
                        process: 'Process 3',
                        name: 'UAT Execution',
                        dueDate: '02 Jun 2026',
                        status: 'Pending',
                        statusIcon: '◷',
                        statusClass: 'status pending-status',
                        leftColor: 'row-line orange-line',
                        isUpcoming: true
                    },
                    {
                        id: 'dt-s1-t6',
                        processKey: 'process4',
                        process: 'Process 4',
                        name: 'Go Live Checklist',
                        dueDate: '25 Jun 2026',
                        status: 'Overdue',
                        statusIcon: '!',
                        statusClass: 'status overdue-status',
                        leftColor: 'row-line red-line',
                        isUpcoming: true
                    }
                ]
            },

            stage2: {
                milestoneLabel: 'Stage 2',
                progress: 42,
                currentProcess: 'Process 1',
                startDate: '01 Jul 2026',
                endDate: '31 Aug 2026',
                firstMonth: 'Jul 2026',
                secondMonth: 'Aug 2026',
                dateRange: 'julAug',
                dateMarkers: ['01 Jul', '08 Jul', '15 Jul', '22 Jul', '29 Jul', '05 Aug', '12 Aug', '19 Aug', '26 Aug', '31 Aug'],
                processes: [
                    {
                        key: 'process1',
                        name: 'Process 1',
                        date: '01 Jul – 15 Jul',
                        rowClass: 'chart-row active-row',
                        barClass: 'timeline-bar blue-bar',
                        style: 'left: 8%; width: 25%;',
                        markerClass: 'bar-marker blue-marker',
                        icon: ''
                    },
                    {
                        key: 'process2',
                        name: 'Process 2',
                        date: '16 Jul – 31 Jul',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar orange-bar',
                        style: 'left: 32%; width: 28%;',
                        markerClass: 'bar-marker orange-marker',
                        icon: ''
                    },
                    {
                        key: 'process3',
                        name: 'Process 3',
                        date: '01 Aug – 18 Aug',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar orange-bar',
                        style: 'left: 55%; width: 27%;',
                        markerClass: 'bar-marker orange-marker',
                        icon: ''
                    }
                ],
                tasks: [
                    {
                        id: 'dt-s2-t1',
                        processKey: 'process1',
                        process: 'Process 1',
                        name: 'Data Collection',
                        dueDate: '07 Jul 2026',
                        status: 'In Progress',
                        statusIcon: '◌',
                        statusClass: 'status progress-status',
                        leftColor: 'row-line blue-line',
                        isUpcoming: true
                    },
                    {
                        id: 'dt-s2-t2',
                        processKey: 'process2',
                        process: 'Process 2',
                        name: 'Configuration Review',
                        dueDate: '25 Jul 2026',
                        status: 'Pending',
                        statusIcon: '◷',
                        statusClass: 'status pending-status',
                        leftColor: 'row-line orange-line',
                        isUpcoming: true
                    },
                    {
                        id: 'dt-s2-t3',
                        processKey: 'process3',
                        process: 'Process 3',
                        name: 'Client Signoff',
                        dueDate: '18 Aug 2026',
                        status: 'Pending',
                        statusIcon: '◷',
                        statusClass: 'status pending-status',
                        leftColor: 'row-line orange-line',
                        isUpcoming: true
                    }
                ]
            },

            stage3: {
                milestoneLabel: 'Stage 3',
                progress: 20,
                currentProcess: 'Process 1',
                startDate: '01 Sep 2026',
                endDate: '31 Oct 2026',
                firstMonth: 'Sep 2026',
                secondMonth: 'Oct 2026',
                dateRange: 'sepOct',
                dateMarkers: ['01 Sep', '08 Sep', '15 Sep', '22 Sep', '29 Sep', '06 Oct', '13 Oct', '20 Oct', '27 Oct', '31 Oct'],
                processes: [
                    {
                        key: 'process1',
                        name: 'Process 1',
                        date: '01 Sep – 15 Sep',
                        rowClass: 'chart-row active-row',
                        barClass: 'timeline-bar blue-bar',
                        style: 'left: 8%; width: 28%;',
                        markerClass: 'bar-marker blue-marker',
                        icon: ''
                    },
                    {
                        key: 'process2',
                        name: 'Process 2',
                        date: '16 Sep – 05 Oct',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar orange-bar',
                        style: 'left: 35%; width: 30%;',
                        markerClass: 'bar-marker orange-marker',
                        icon: ''
                    },
                    {
                        key: 'process3',
                        name: 'Process 3',
                        date: '06 Oct – 31 Oct',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar red-bar',
                        style: 'left: 62%; width: 34%;',
                        markerClass: 'bar-marker red-marker',
                        icon: '⚑'
                    }
                ],
                tasks: [
                    {
                        id: 'dt-s3-t1',
                        processKey: 'process1',
                        process: 'Process 1',
                        name: 'Deployment Planning',
                        dueDate: '10 Sep 2026',
                        status: 'In Progress',
                        statusIcon: '◌',
                        statusClass: 'status progress-status',
                        leftColor: 'row-line blue-line',
                        isUpcoming: true
                    },
                    {
                        id: 'dt-s3-t2',
                        processKey: 'process2',
                        process: 'Process 2',
                        name: 'Production Validation',
                        dueDate: '30 Sep 2026',
                        status: 'Pending',
                        statusIcon: '◷',
                        statusClass: 'status pending-status',
                        leftColor: 'row-line orange-line',
                        isUpcoming: true
                    },
                    {
                        id: 'dt-s3-t3',
                        processKey: 'process3',
                        process: 'Process 3',
                        name: 'Go Live Approval',
                        dueDate: '25 Oct 2026',
                        status: 'Pending',
                        statusIcon: '◷',
                        statusClass: 'status pending-status',
                        leftColor: 'row-line red-line',
                        isUpcoming: true
                    }
                ]
            }
        },

        salesforceImplementation: {
            stage1: {
                milestoneLabel: 'Stage 1',
                progress: 75,
                currentProcess: 'Process 3',
                startDate: '01 May 2026',
                endDate: '30 Jun 2026',
                firstMonth: 'May 2026',
                secondMonth: 'Jun 2026',
                dateRange: 'mayJun',
                dateMarkers: ['27 Apr', '04 May', '11 May', '18 May', '25 May', '01 Jun', '08 Jun', '15 Jun', '22 Jun', '29 Jun'],
                processes: [
                    {
                        key: 'process1',
                        name: 'Process 1',
                        date: '01 May – 08 May',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar green-bar',
                        style: 'left: 4%; width: 18%;',
                        markerClass: 'bar-marker green-marker',
                        icon: '✓'
                    },
                    {
                        key: 'process2',
                        name: 'Process 2',
                        date: '09 May – 24 May',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar green-bar',
                        style: 'left: 20%; width: 28%;',
                        markerClass: 'bar-marker green-marker',
                        icon: '✓'
                    },
                    {
                        key: 'process3',
                        name: 'Process 3',
                        date: '25 May – 15 Jun',
                        rowClass: 'chart-row active-row',
                        barClass: 'timeline-bar blue-bar',
                        style: 'left: 45%; width: 32%;',
                        markerClass: 'bar-marker blue-marker',
                        icon: ''
                    },
                    {
                        key: 'process4',
                        name: 'Process 4',
                        date: '16 Jun – 30 Jun',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar orange-bar',
                        style: 'left: 75%; width: 22%;',
                        markerClass: 'bar-marker orange-marker',
                        icon: ''
                    }
                ],
                tasks: [
                    {
                        id: 'sf-s1-t1',
                        processKey: 'process1',
                        process: 'Process 1',
                        name: 'Requirement Workshop',
                        dueDate: '05 May 2026',
                        status: 'Completed',
                        statusIcon: '✓',
                        statusClass: 'status completed-status',
                        leftColor: 'row-line green-line',
                        isUpcoming: false
                    },
                    {
                        id: 'sf-s1-t2',
                        processKey: 'process2',
                        process: 'Process 2',
                        name: 'Solution Design',
                        dueDate: '20 May 2026',
                        status: 'Completed',
                        statusIcon: '✓',
                        statusClass: 'status completed-status',
                        leftColor: 'row-line green-line',
                        isUpcoming: false
                    },
                    {
                        id: 'sf-s1-t3',
                        processKey: 'process3',
                        process: 'Process 3',
                        name: 'LWC Development',
                        dueDate: '10 Jun 2026',
                        status: 'In Progress',
                        statusIcon: '◌',
                        statusClass: 'status progress-status',
                        leftColor: 'row-line blue-line',
                        isUpcoming: true
                    },
                    {
                        id: 'sf-s1-t4',
                        processKey: 'process4',
                        process: 'Process 4',
                        name: 'UAT Signoff',
                        dueDate: '28 Jun 2026',
                        status: 'Pending',
                        statusIcon: '◷',
                        statusClass: 'status pending-status',
                        leftColor: 'row-line orange-line',
                        isUpcoming: true
                    }
                ]
            }
        },

        serviceAutomation: {
            stage1: {
                milestoneLabel: 'Stage 1',
                progress: 55,
                currentProcess: 'Process 2',
                startDate: '01 May 2026',
                endDate: '30 Jun 2026',
                firstMonth: 'May 2026',
                secondMonth: 'Jun 2026',
                dateRange: 'mayJun',
                dateMarkers: ['27 Apr', '04 May', '11 May', '18 May', '25 May', '01 Jun', '08 Jun', '15 Jun', '22 Jun', '29 Jun'],
                processes: [
                    {
                        key: 'process1',
                        name: 'Process 1',
                        date: '01 May – 12 May',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar green-bar',
                        style: 'left: 5%; width: 22%;',
                        markerClass: 'bar-marker green-marker',
                        icon: '✓'
                    },
                    {
                        key: 'process2',
                        name: 'Process 2',
                        date: '13 May – 05 Jun',
                        rowClass: 'chart-row active-row',
                        barClass: 'timeline-bar blue-bar',
                        style: 'left: 28%; width: 36%;',
                        markerClass: 'bar-marker blue-marker',
                        icon: ''
                    },
                    {
                        key: 'process3',
                        name: 'Process 3',
                        date: '06 Jun – 30 Jun',
                        rowClass: 'chart-row',
                        barClass: 'timeline-bar red-bar',
                        style: 'left: 62%; width: 35%;',
                        markerClass: 'bar-marker red-marker',
                        icon: '⚑'
                    }
                ],
                tasks: [
                    {
                        id: 'sa-s1-t1',
                        processKey: 'process1',
                        process: 'Process 1',
                        name: 'Service Flow Review',
                        dueDate: '08 May 2026',
                        status: 'Completed',
                        statusIcon: '✓',
                        statusClass: 'status completed-status',
                        leftColor: 'row-line green-line',
                        isUpcoming: false
                    },
                    {
                        id: 'sa-s1-t2',
                        processKey: 'process2',
                        process: 'Process 2',
                        name: 'Mobile App Setup',
                        dueDate: '25 May 2026',
                        status: 'In Progress',
                        statusIcon: '◌',
                        statusClass: 'status progress-status',
                        leftColor: 'row-line blue-line',
                        isUpcoming: true
                    },
                    {
                        id: 'sa-s1-t3',
                        processKey: 'process3',
                        process: 'Process 3',
                        name: 'Technician Testing',
                        dueDate: '20 Jun 2026',
                        status: 'Overdue',
                        statusIcon: '!',
                        statusClass: 'status overdue-status',
                        leftColor: 'row-line red-line',
                        isUpcoming: true
                    }
                ]
            }
        }
    };

    handleProjectChange(event) {
        this.selectedProject = event.target.value;
        this.selectedMilestone = 'stage1';
        this.selectedStage = 'all';

        const currentData = this.currentData;
        if (currentData) {
            this.selectedDateRange = currentData.dateRange;
        }
    }

    handleMilestoneChange(event) {
        this.selectedMilestone = event.target.value;
        this.selectedStage = 'all';

        const currentData = this.currentData;
        if (currentData) {
            this.selectedDateRange = currentData.dateRange;
        }
    }

    handleStageChange(event) {
        this.selectedStage = event.target.value;
    }

    handleDateRangeChange(event) {
        this.selectedDateRange = event.target.value;
    }

    handleReset() {
        this.selectedProject = 'digitalTransformation';
        this.selectedMilestone = 'stage1';
        this.selectedStage = 'all';
        this.selectedDateRange = 'mayJun';
    }

    get currentData() {
        const projectData = this.demoData[this.selectedProject];

        if (!projectData) {
            return null;
        }

        return projectData[this.selectedMilestone] || projectData.stage1;
    }

    get filteredByDateRange() {
        if (!this.currentData) {
            return null;
        }

        if (this.currentData.dateRange === this.selectedDateRange) {
            return this.currentData;
        }

        return {
            ...this.currentData,
            processes: [],
            tasks: []
        };
    }

    get currentMilestoneLabel() {
        return this.currentData ? this.currentData.milestoneLabel : '-';
    }

    get progressValue() {
        return this.filteredByDateRange ? this.filteredByDateRange.progress : 0;
    }

    get progressStyle() {
        return `background: conic-gradient(#1b74e4 ${this.progressValue}%, #e5e7eb 0);`;
    }

    get currentProcess() {
        return this.filteredByDateRange ? this.filteredByDateRange.currentProcess : '-';
    }

    get startDate() {
        return this.filteredByDateRange ? this.filteredByDateRange.startDate : '-';
    }

    get endDate() {
        return this.filteredByDateRange ? this.filteredByDateRange.endDate : '-';
    }

    get firstMonth() {
        return this.filteredByDateRange ? this.filteredByDateRange.firstMonth : '-';
    }

    get secondMonth() {
        return this.filteredByDateRange ? this.filteredByDateRange.secondMonth : '-';
    }

    get dateMarkers() {
        return this.filteredByDateRange ? this.filteredByDateRange.dateMarkers : [];
    }

    get filteredProcessRows() {
        const data = this.filteredByDateRange;

        if (!data || !data.processes) {
            return [];
        }

        if (this.selectedStage === 'all') {
            return data.processes;
        }

        return data.processes.filter(item => item.key === this.selectedStage);
    }

    get filteredTaskRows() {
        const data = this.filteredByDateRange;

        if (!data || !data.tasks) {
            return [];
        }

        if (this.selectedStage === 'all') {
            return data.tasks;
        }

        return data.tasks.filter(item => item.processKey === this.selectedStage);
    }

    get filteredUpcomingTasks() {
        return this.filteredTaskRows
            .filter(task => task.isUpcoming)
            .map(task => {
                let iconClass = 'upcoming-icon gray-icon';
                let dateClass = 'upcoming-date';

                if (task.status === 'In Progress') {
                    iconClass = 'upcoming-icon orange-icon';
                    dateClass = 'upcoming-date orange-text';
                }

                if (task.status === 'Overdue') {
                    iconClass = 'upcoming-icon red-icon';
                    dateClass = 'upcoming-date red-text';
                }

                return {
                    id: task.id,
                    name: task.name,
                    process: task.process,
                    date: task.dueDate,
                    status: task.status,
                    icon: task.status === 'Overdue' ? '!' : '◷',
                    iconClass: iconClass,
                    dateClass: dateClass
                };
            });
    }

    get hasProcessRows() {
        return this.filteredProcessRows.length > 0;
    }

    get hasTaskRows() {
        return this.filteredTaskRows.length > 0;
    }

    get hasUpcomingTasks() {
        return this.filteredUpcomingTasks.length > 0;
    }

    get taskCountText() {
        const count = this.filteredTaskRows.length;
        return count === 0 ? '0 task' : `1–${count} of ${count} tasks`;
    }

    get noteText() {
        const processCount = this.filteredProcessRows.length;
        const taskCount = this.filteredTaskRows.length;
        return `${this.currentMilestoneLabel} includes ${processCount} processes and ${taskCount} tasks.`;
    }
}