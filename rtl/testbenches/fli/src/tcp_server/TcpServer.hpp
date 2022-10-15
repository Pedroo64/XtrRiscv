#pragma once
#include <stdint.h>
#include <winsock2.h>

class TcpServer
{
private:
    SOCKET m_listen_socket, m_client_socket;
private:
    int set_blocking(SOCKET fd, bool blocking);
public:
    TcpServer();
    ~TcpServer();
    int init(uint16_t port);
    int init();
    void end();
    int listen(bool blocking = true);
    void close_listen() { closesocket(m_listen_socket); };
    void close_client() { closesocket(m_client_socket); };
    int accept();
    int recv(void *ptr_buf, int size, bool blocking = true);
    int send(const void *ptr_buf, int size);
    bool is_listening() { return m_listen_socket > 0 ? true : false; };
    bool is_connected() { return m_client_socket > 0 ? true : false; };
};