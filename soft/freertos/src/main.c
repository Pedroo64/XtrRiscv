#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "dev/io.h"
#include "dev/uart.h"
#include "riscv/csr.h"

extern void freertos_risc_v_trap_handler(void);

void freertos_risc_v_application_interrupt_handler(uint32_t cause) {
    uart_puts(UART0_BASE, "Hello from interrupt\n\r");
}

TaskHandle_t task1_handler = NULL, task2_handler = NULL;
SemaphoreHandle_t semaphore_handler = NULL;

void task1(void * parameters) {
    for (;;) {
        xSemaphoreTake(semaphore_handler, portMAX_DELAY);
        uart_puts(UART0_BASE, "Hello from task1\n\r");
        xSemaphoreGive(semaphore_handler);
#ifdef SIM_BUILD
        vTaskDelay(5);
#else
        vTaskDelay(pdMS_TO_TICKS(500));
#endif
    }
}
void task2(void * parameters) {
    (void)parameters;
    for (;;) {
        xSemaphoreTake(semaphore_handler, portMAX_DELAY);
        uart_puts(UART0_BASE, "Hello from task2\n\r");
        xSemaphoreGive(semaphore_handler);
#ifdef SIM_BUILD
        vTaskDelay(5);
#else
        vTaskDelay(pdMS_TO_TICKS(500));
#endif
    }
}

int main(int argc, char const *argv[]) {
    uart_puts(UART0_BASE, "Starting...\n\r");

    csr_write(mtvec, freertos_risc_v_trap_handler);

    BaseType_t status1, status2;

    status1 = xTaskCreate(
        task1,
        "task1",
        configMINIMAL_STACK_SIZE*2,
        NULL,
        configMAX_PRIORITIES-1,
        &task1_handler
    );
    
    status2 = xTaskCreate(
        task2,
        "task1",
        configMINIMAL_STACK_SIZE*2,
        NULL,
        configMAX_PRIORITIES-1,
        &task2_handler
    );

    semaphore_handler = xSemaphoreCreateMutex();

    uart_puts(UART0_BASE, "Created task...\n\r");

    if (status1 != pdPASS) {
        uart_puts(UART0_BASE, "Could not create task1\n\r");
    }
    if (status2 != pdPASS) {
        uart_puts(UART0_BASE, "Could not create task2\n\r");
    }
    if (semaphore_handler == NULL) {
        uart_puts(UART0_BASE, "Could not create a mutex\n\r");
    }

    uart_puts(UART0_BASE, "Starting scheduler...\n\r");

    /* Start the scheduler. */
    vTaskStartScheduler();

    uart_puts(UART0_BASE, "Could not start scheduler\n\r");

    return 0;
}
