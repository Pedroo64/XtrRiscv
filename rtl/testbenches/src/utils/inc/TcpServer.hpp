#pragma once
#include <stdint.h>
#ifdef WIN32
#include <winsock2.h>
typedef SOCKET socket_t;
#else
typedef int socket_t;
#endif


class TcpServer {
public:
    TcpServer();
    ~TcpServer();
    int init(uint16_t port);
    int end();
    int listen(bool blocking = true);
    void close_listen() { closesocket(m_listen_socket); };
    void close_client() { closesocket(m_client_socket); };
    int accept();
    int recv(void *ptr_buf, size_t size, bool blocking = true);
    int send(const void *ptr_buf, size_t size);
    bool is_listening() { return (bool)(m_listen_socket > 0); };
    bool is_connected() { return (bool)(m_client_socket > 0); };
private:
    int set_blocking(socket_t fd, bool blocking);
private:
    socket_t m_listen_socket, m_client_socket;
};
