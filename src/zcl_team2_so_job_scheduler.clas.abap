**********************************************************************
* Class: Schedule Daily Sales Order Overdue Job
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 13/10/2026
* Content explanation:
*   Schedule the Sales Order Overdue background job.
*   Configure the job to run once per day at 00:05 Vietnam time.
*   The BTP system timezone is UTC, so the schedule uses UTC+7.
*   Stop the recurring schedule after 365 executions.
*---------------------------------------------------------------------*
* Job Template:
* --> ZJOBT_TEAM2_SO_OVERDUE
*---------------------------------------------------------------------*
CLASS zcl_team2_so_job_scheduler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.

    CONSTANTS:
      lc_job_template TYPE cl_apj_rt_api=>ty_template_name VALUE 'ZJOBT_TEAM2_SO_OVERDUE',
      lc_job_text     TYPE cl_apj_rt_api=>ty_job_text      VALUE 'TEAM2_SO_OVERDUE_DAILY',
      " Vietnam time. The system timezone of BTP is UTC: 00:05 system time
      " would run the job at 07:05 in Vietnam.
      lc_timezone     TYPE timezone                        VALUE 'UTC+7',
      lc_start_time   TYPE t                               VALUE '000500'.

ENDCLASS.


CLASS zcl_team2_so_job_scheduler IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
**********************************************************************
* Main: Schedule Recurring Sales Order Overdue Job
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 11/10/2026
* Content explanation:
*   Determine the current date in Vietnam time (UTC+7).
*   Schedule the first execution for the next 00:05 Vietnam time.
*   Configure a daily recurring Application Job.
*   Limit the recurring schedule to 365 executions.
*   Output the created Job Name and Job Count after scheduling.
*---------------------------------------------------------------------*
* Parameters:
* --> OUT            : Console output of the ADT class execution
*---------------------------------------------------------------------*
    DATA:
      ls_start_info      TYPE cl_apj_rt_api=>ty_start_info,
      ls_scheduling_info TYPE cl_apj_rt_api=>ty_scheduling_info,
      ls_end_info        TYPE cl_apj_rt_api=>ty_end_info,
      lv_jobname         TYPE cl_apj_rt_api=>ty_jobname,
      lv_jobcount        TYPE cl_apj_rt_api=>ty_jobcount,
      lv_date            TYPE d,
      lv_time            TYPE t,
      lv_now             TYPE timestamp,
      lv_start_timestamp TYPE timestamp.

    " Get the current timestamp.
    GET TIME STAMP FIELD lv_now.

    " Convert the current timestamp to Vietnam time.
    CONVERT TIME STAMP lv_now
      TIME ZONE lc_timezone
      INTO DATE lv_date TIME lv_time.

    " First execution: the next 00:05 Vietnam time (today if not yet passed).
    IF lv_time >= lc_start_time.
      lv_date = lv_date + 1.
    ENDIF.

    " Convert the local execution time to a UTC timestamp.
    CONVERT DATE lv_date TIME lc_start_time
      INTO TIME STAMP lv_start_timestamp
      TIME ZONE lc_timezone.

    " Set the first execution timestamp.
    ls_start_info-timestamp = lv_start_timestamp.

    " Configure daily recurrence.
    ls_scheduling_info-periodic_granularity = cl_apj_rt_api=>period_days.
    ls_scheduling_info-periodic_value       = 1.
    ls_scheduling_info-test_mode            = abap_false.
    ls_scheduling_info-timezone             = lc_timezone.

    " Stop the recurring schedule after 365 executions.
    ls_end_info-type           = cl_apj_rt_api=>period_end_by_nr_of_executions.
    ls_end_info-max_iterations = 365.

    TRY.

        " Schedule the recurring Sales Order Overdue Job.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name = lc_job_template
            iv_job_text          = lc_job_text
            is_start_info        = ls_start_info
            is_scheduling_info   = ls_scheduling_info
            is_end_info          = ls_end_info
          IMPORTING
            ev_jobname           = lv_jobname
            ev_jobcount          = lv_jobcount
        ).

        " Output scheduling information.
        out->write( |Job scheduled successfully.| ).
        out->write( |Job Name: { lv_jobname }| ).
        out->write( |Job Count: { lv_jobcount }| ).
        out->write( |First run: { lv_date DATE = ISO } 00:05 ({ lc_timezone })| ).
        out->write( |Frequency: Every day at 00:05 ({ lc_timezone })| ).

      CATCH cx_apj_rt INTO DATA(lx_job).

        " Output scheduling error information.
        out->write( |Job scheduling failed.| ).
        out->write( lx_job->get_text( ) ).
    ENDTRY.

  ENDMETHOD.
ENDCLASS.
